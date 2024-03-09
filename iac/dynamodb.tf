resource "aws_dynamodb_table" "tenant_quota" {
  tags = {
    "target" : "admin"
  }
  stream_enabled              = true
  stream_view_type            = "NEW_AND_OLD_IMAGES"
  name                        = "tenant-quota"
  hash_key                    = "TenantId"
  deletion_protection_enabled = false
  billing_mode                = "PAY_PER_REQUEST"

  attribute {
    type = "S"
    name = "TenantId"
  }
  

}
