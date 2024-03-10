terraform {
  backend "s3" {
    bucket         = "tflock-multiple-tenant"
    key            = "state/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "tflock"
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-northeast-1"
}