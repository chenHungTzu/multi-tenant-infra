
resource "aws_s3_bucket" "codepipeline_bucket" {
  tags   = merge(var.tags, {})
  bucket = "tf-pipeline-bucket"
}


resource "aws_codecommit_repository" "codecommit" {
  tags            = merge(var.tags, {})
  repository_name = "tf-codecommit"
}

resource "aws_iam_role" "codepipeline_role" {
  name               = "pipeline-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}


resource "aws_iam_role_policy" "codepipeline_policy" {
  role   = aws_iam_role.codepipeline_role.id
  policy = data.aws_iam_policy_document.codepipeline_policy.json
}


data "aws_iam_policy_document" "codepipeline_policy" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObjectAcl",
      "s3:PutObject",
    ]

    resources = [
      aws_s3_bucket.codepipeline_bucket.arn,
      "${aws_s3_bucket.codepipeline_bucket.arn}/*"
    ]
  }
  statement {
    effect = "Allow"

    actions = [
      "codecommit:CancelUploadArchive",
      "codecommit:GetBranch",
      "codecommit:GetCommit",
      "codecommit:GetRepository",
      "codecommit:GetUploadArchiveStatus",
      "codecommit:UploadArchive"
    ]

    resources = [
      aws_codecommit_repository.codecommit.arn,
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "codebuild:*",
    ]

    resources = [
      aws_codebuild_project.project.arn,
    ]
  }

}



resource "aws_codepipeline" "codepipeline" {
  tags     = merge(var.tags, {})
  role_arn = aws_iam_role.codepipeline_role.arn
  name     = "tf-codepipeline"

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.codepipeline_bucket.bucket
  }

  depends_on = [aws_iam_role.codepipeline_role]


  stage {
    name = "Clone"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      input_artifacts  = []
      version          = "1"
      output_artifacts = ["CodeWorkspace"]
      configuration = {
        RepositoryName       = "${aws_codecommit_repository.codecommit.repository_name}"
        BranchName           = "main"
        PollForSourceChanges = false
      }
    }

  }
  stage {
    name = "Build"

    action {
      run_order        = 1
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["CodeWorkspace"]
      output_artifacts = ["TerraformPlanFile"]
      version          = "1"

      configuration = {
        ProjectName = "${aws_codebuild_project.project.name}"
       
      }
    }

  }
}

resource "aws_codebuild_project" "project" {
  tags          = merge(var.tags, {})
  name          = "tf-codebuild"
  build_timeout = "5"
  service_role  = aws_iam_role.codebuild_role.arn
  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

  }
  source {
    type = "CODEPIPELINE"
  }
}

resource "aws_iam_role" "codebuild_role" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codebuild_role_policy" {
  role   = aws_iam_role.codebuild_role.name
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "sts:AssumeRole",
        "codebuild:*",
        "lambda:*",
        "iam:*",
        "dynamodb:*",
        "apigateway:*",
        "codecommit:*",
        "events:*",
        "codepipeline:*"

      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
POLICY
}

resource "aws_cloudwatch_event_rule" "cloudwatch_event_rule" {
  tags          = merge(var.tags, {})
  name_prefix   = "cloudwatch_event_rule"
  event_pattern = <<PATTERN
{
  "source": [ "aws.codecommit" ],
  "detail-type": [ "CodeCommit Repository State Change" ],
  "resources": [ "${aws_codecommit_repository.codecommit.arn}" ],
  "detail": {
     "event": [
       "referenceCreated",
       "referenceUpdated"
      ],
     "referenceType":["branch"],
     "referenceName": ["main"]
  }
}
PATTERN
}

resource "aws_cloudwatch_event_target" "cloudwatch_event_trigger" {
  target_id = "cloudwatch_event_trigger"
  rule      = aws_cloudwatch_event_rule.cloudwatch_event_rule.name
  arn       = aws_codepipeline.codepipeline.arn
  role_arn  = aws_iam_role.cloudwatch_pipeline_trigger_role.arn
}

resource "aws_iam_role" "cloudwatch_pipeline_trigger_role" {
  assume_role_policy = <<DOC
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
DOC
}


data "aws_iam_policy_document" "cloudwatch_pipeline_trigger_policy_document" {
  statement {
    actions = [
      "iam:PassRole"
    ]
    resources = [
      "*"
    ]
  }
  statement {
    actions = [
      "codepipeline:StartPipelineExecution"
    ]
    resources = [
      aws_codepipeline.codepipeline.arn
    ]
  }
}

resource "aws_iam_policy" "cloudwatch_pipeline_trigger_policy" {
  policy = data.aws_iam_policy_document.cloudwatch_pipeline_trigger_policy_document.json
}
resource "aws_iam_role_policy_attachment" "cloudwatch_pipeline_trigger_policy_attachment" {
  policy_arn = aws_iam_policy.cloudwatch_pipeline_trigger_policy.arn
  role       = aws_iam_role.cloudwatch_pipeline_trigger_role.name
}