variable "api-gateway-name-client" {}
variable "region" {}
variable "stage_name" {}
variable "stage_deployed_at" {}
variable "environment" {}
variable "image_uri_base" {}
variable "lambdas_client_post" {
  type = map(any)
}