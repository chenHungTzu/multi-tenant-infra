// Create a resource (for custom root)
resource "aws_api_gateway_resource" "multi_tenant_api_gateway_custom_root_resource" {
  count       = length(var.input) == 0 ? 0 : 1
  rest_api_id = aws_api_gateway_rest_api.multi_tenant_api_gateway.id
  path_part   = "custom"
  parent_id   = aws_api_gateway_rest_api.multi_tenant_api_gateway.root_resource_id
}

resource "aws_api_gateway_resource" "multi_tenant_api_gateway_custom_tenant_resource" {
  count       = length(var.input) == 0 ? 0 : 1
  rest_api_id = aws_api_gateway_rest_api.multi_tenant_api_gateway.id
  path_part   = "{tenantId}"
  parent_id   = aws_api_gateway_resource.multi_tenant_api_gateway_custom_root_resource[0].id
}

resource "aws_api_gateway_resource" "multi_tenant_api_gateway_custom_proxy_resource" {
  count       = length(var.input) == 0 ? 0 : 1
  rest_api_id = aws_api_gateway_rest_api.multi_tenant_api_gateway.id
  path_part   = "{proxy+}"
  parent_id   = aws_api_gateway_resource.multi_tenant_api_gateway_custom_tenant_resource[0].id


}

resource "aws_api_gateway_method" "multi_tenant_api_gateway_any_resource_method" {
  count            = length(var.input) == 0 ? 0 : 1
  rest_api_id      = aws_api_gateway_rest_api.multi_tenant_api_gateway.id
  resource_id      = aws_api_gateway_resource.multi_tenant_api_gateway_custom_proxy_resource[0].id
  http_method      = "ANY"
  authorization    = "NONE"
  api_key_required = true

  request_parameters = {
    "method.request.path.tenantId" = true
  }
}


// intergrate the method with mock
resource "aws_api_gateway_integration" "multi_tenant_api_gateway_custom_any_method_integration" {
  for_each    = var.input
  rest_api_id = aws_api_gateway_rest_api.multi_tenant_api_gateway.id
  resource_id = aws_api_gateway_method.multi_tenant_api_gateway_any_resource_method[0].resource_id
  http_method = aws_api_gateway_method.multi_tenant_api_gateway_any_resource_method[0].http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
  request_parameters = {
    "integration.request.path.tenantId" = "method.request.path.tenantId"
  }
}


// customer key
resource "aws_api_gateway_api_key" "custom" {
  for_each = var.input
  name     = each.key

  depends_on = [aws_api_gateway_resource.multi_tenant_api_gateway_custom_root_resource]
}

// custom's usage plan
resource "aws_api_gateway_usage_plan" "custom" {
  for_each     = var.input
  name         = "custom-usage-plan-${each.key}"
  product_code = "muti-tenant-custom"
  api_stages {
    api_id = aws_api_gateway_rest_api.multi_tenant_api_gateway.id
    stage  = aws_api_gateway_deployment.agw_deployment.stage_name
    throttle {
      path        = "/${aws_api_gateway_resource.multi_tenant_api_gateway_custom_root_resource[0].path_part}/{tenantId}/{proxy+}/ANY"
      burst_limit = each.value.RateLimit
      rate_limit  = each.value.BurstLimit
    }
  }

  quota_settings {
    limit  = each.value.QuotaLimit
    offset = each.value.QuotaOffeset
    period = each.value.QuotaPeriod
  }

  throttle_settings {
    burst_limit = 1
    rate_limit  = 1
  }
}

resource "aws_api_gateway_usage_plan_key" "custom" {
  for_each      = var.input
  key_id        = aws_api_gateway_api_key.custom[each.key].id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.custom[each.key].id
}



resource "aws_api_gateway_method_response" "customer_response_200" {
  count       = length(var.input) == 0 ? 0 : 1
  rest_api_id = aws_api_gateway_rest_api.multi_tenant_api_gateway.id
  resource_id = aws_api_gateway_resource.multi_tenant_api_gateway_custom_proxy_resource[0].id
  http_method = aws_api_gateway_method.multi_tenant_api_gateway_any_resource_method[0].http_method

  status_code = "200"
  depends_on = [
    aws_api_gateway_rest_api.multi_tenant_api_gateway,
    # aws_api_gateway_resource.multi_tenant_api_gateway_custom_proxy_resource[each.key],
    # aws_api_gateway_method.multi_tenant_api_gateway_any_resource_method[each.key]
  ]
}

resource "aws_api_gateway_integration_response" "customer_response_200" {
  count       = length(var.input) == 0 ? 0 : 1
  rest_api_id = aws_api_gateway_rest_api.multi_tenant_api_gateway.id
  resource_id = aws_api_gateway_resource.multi_tenant_api_gateway_custom_proxy_resource[0].id
  http_method = aws_api_gateway_method.multi_tenant_api_gateway_any_resource_method[0].http_method
  status_code = aws_api_gateway_method_response.customer_response_200[0].status_code


  response_templates = {
    "application/json" = "EMPTY"
  }

  depends_on = [
    aws_api_gateway_rest_api.multi_tenant_api_gateway,
    # aws_api_gateway_resource.multi_tenant_api_gateway_custom_proxy_resource[each.key],
    # aws_api_gateway_method.multi_tenant_api_gateway_any_resource_method[each.key],
    # aws_api_gateway_integration.multi_tenant_api_gateway_custom_any_method_integration[each.key],
    # aws_api_gateway_method_response.customer_response_200[each.key],
  ]
}
