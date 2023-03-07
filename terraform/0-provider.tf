locals {
  region = var.region
  common_tags = {
    Owner       = "IT"
    Environment = var.environment
    platform    = "pichincha"
  }
 pichincha_apikey = jsondecode(data.aws_secretsmanager_secret_version.pichincha_apikey.secret_string)
}
provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

data "aws_secretsmanager_secret_version" "pichincha_apikey" {
  secret_id = "${var.environment}/pichincha-${var.environment}/apitoken"
}
