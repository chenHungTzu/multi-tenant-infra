// agw execution role

# The policy document to access the role
data "aws_iam_policy_document" "agw_admin_policy" {
  depends_on = [aws_dynamodb_table.tenant_quota]
  statement {
    sid = ""
    actions = [
      "dynamodb:*",
    ]
    resources = [
      aws_dynamodb_table.tenant_quota.arn,
    ]
  }
}

# The IAM Role for the execution
resource "aws_iam_role" "api_gateway_admin_role" {
  name               = "api_gateway_admin_role"
  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "apigateway.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy" "example_policy" {
  name   = "example_policy"
  role   = aws_iam_role.api_gateway_admin_role.id
  policy = data.aws_iam_policy_document.agw_admin_policy.json
}


resource "aws_api_gateway_rest_api" "multi_tenant_api_gateway" {
  tags = merge(var.tags, {})
  name = "multi-tenant-api-gateway"
}


// deploy the api gateway
resource "aws_api_gateway_deployment" "agw_deployment" {
  stage_name  = "dev"
  rest_api_id = aws_api_gateway_rest_api.multi_tenant_api_gateway.id

  triggers = {
    redeployment = sha256(jsonencode(aws_api_gateway_method.multi_tenant_api_gateway_any_resource_method))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.multi_tenant_api_gateway_admin_ddb_method,
    aws_api_gateway_method.multi_tenant_api_gateway_any_resource_method,
    aws_api_gateway_integration.multi_tenant_api_gateway_admin_ddb_method_integration,
    aws_api_gateway_integration.multi_tenant_api_gateway_custom_any_method_integration
  ]
}