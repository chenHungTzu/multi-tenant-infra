// admin key
resource "aws_api_gateway_api_key" "admin" {
  name = "admin"
}

// admin's usage plan
resource "aws_api_gateway_usage_plan" "admin" {
  name         = "admin-usage-plan"
  product_code = "muti-tenant-admin"

  api_stages {
    api_id = aws_api_gateway_rest_api.multi_tenant_api_gateway.id
    stage  = aws_api_gateway_deployment.agw_deployment.stage_name
    throttle {
      path        = "/${aws_api_gateway_resource.multi_tenant_api_gateway_admin_root_resource.path_part}/${aws_api_gateway_resource.multi_tenant_api_gateway_admin_ddb_resource.path_part}/POST"
      burst_limit = 1
      rate_limit  = 1
    }
  }

  quota_settings {
    limit  = 100
    offset = 0
    period = "DAY"
  }

  throttle_settings {
    burst_limit = 5
    rate_limit  = 10
  }
}

resource "aws_api_gateway_usage_plan_key" "admin" {
  key_id        = aws_api_gateway_api_key.admin.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.admin.id
}

// Create a resource (for admin root)
resource "aws_api_gateway_resource" "multi_tenant_api_gateway_admin_root_resource" {
  rest_api_id = aws_api_gateway_rest_api.multi_tenant_api_gateway.id
  path_part   = "admin"
  parent_id   = aws_api_gateway_rest_api.multi_tenant_api_gateway.root_resource_id
}

// Create a resource (for tenant-quota resource)
resource "aws_api_gateway_resource" "multi_tenant_api_gateway_admin_ddb_resource" {
  rest_api_id = aws_api_gateway_rest_api.multi_tenant_api_gateway.id
  path_part   = "tenant-quota"
  parent_id   = aws_api_gateway_resource.multi_tenant_api_gateway_admin_root_resource.id
}


// Create a method for the resource
resource "aws_api_gateway_method" "multi_tenant_api_gateway_admin_ddb_method" {
  rest_api_id      = aws_api_gateway_rest_api.multi_tenant_api_gateway.id
  resource_id      = aws_api_gateway_resource.multi_tenant_api_gateway_admin_ddb_resource.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = true
}

// intergrate the method with dynamodb
resource "aws_api_gateway_integration" "multi_tenant_api_gateway_admin_ddb_method_integration" {
  rest_api_id             = aws_api_gateway_rest_api.multi_tenant_api_gateway.id
  resource_id             = aws_api_gateway_resource.multi_tenant_api_gateway_admin_ddb_resource.id
  http_method             = aws_api_gateway_method.multi_tenant_api_gateway_admin_ddb_method.http_method
  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:dynamodb:action/PutItem"
  credentials             = aws_iam_role.api_gateway_dynamodb_role.arn

  request_templates = {
    "application/json" = <<EOF
      {
        "TableName": "${aws_dynamodb_table.tenant_quota.name}",
        "Item": {
	        "TenantId": {
              "S": "$input.path('$.TenantId')"
          },
          "QuotaOffeset": {
              "N": "$input.path('$.QuotaOffeset')"
          },
          "QuotaLimit": {
              "N": "$input.path('$.QuotaLimit')"
          },
          "QuotaPeriod": {
              "S": "$input.path('$.QuotaPeriod')"
          },
           "BurstLimit": {
              "N": "$input.path('$.BurstLimit')"
          },
           "RateLimit": {
              "N": "$input.path('$.RateLimit')"
          }

       
        }
      }
    EOF
  }
}

resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.multi_tenant_api_gateway.id
  resource_id = aws_api_gateway_resource.multi_tenant_api_gateway_admin_ddb_resource.id
  http_method = aws_api_gateway_method.multi_tenant_api_gateway_admin_ddb_method.http_method

  status_code = "200"
  depends_on = [
    aws_api_gateway_rest_api.multi_tenant_api_gateway,
    aws_api_gateway_resource.multi_tenant_api_gateway_admin_ddb_resource,
    aws_api_gateway_method.multi_tenant_api_gateway_admin_ddb_method,
  ]
}

resource "aws_api_gateway_integration_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.multi_tenant_api_gateway.id
  resource_id = aws_api_gateway_resource.multi_tenant_api_gateway_admin_ddb_resource.id
  http_method = aws_api_gateway_method.multi_tenant_api_gateway_admin_ddb_method.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code


  response_templates = {
    "application/json" = "EMPTY"
  }

  depends_on = [
    aws_api_gateway_rest_api.multi_tenant_api_gateway,
    aws_api_gateway_resource.multi_tenant_api_gateway_admin_ddb_resource,
    aws_api_gateway_method.multi_tenant_api_gateway_admin_ddb_method,
    aws_api_gateway_integration.multi_tenant_api_gateway_admin_ddb_method_integration,
    aws_api_gateway_method_response.response_200,
  ]
}


