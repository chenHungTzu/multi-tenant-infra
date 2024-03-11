output "agw_api_gateway" {
  value = aws_api_gateway_deployment.agw_deployment.invoke_url
}
output "adminkey" {
  value = nonsensitive(aws_api_gateway_api_key.admin.value)
}

output "customerkey" {
  value = { for k, v in aws_api_gateway_api_key.custom : k => {
    name  = v.name
    value = nonsensitive(v.value)
  } }
}