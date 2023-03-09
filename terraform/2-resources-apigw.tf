resource "aws_lambda_function" "lambda_functions_client" {
  for_each      = var.lambdas_client_post
  function_name = join("-", ["pichincha", each.value.name, var.environment])
  role          = aws_iam_role.pichincha_lambdas.arn
  memory_size   = 2048
  timeout       = 60
  image_uri     = var.image_uri_base
  lifecycle {
    ignore_changes = [image_uri]
  }
  package_type  = "Image"
}

resource "aws_lambda_permission" "apigw_lambda_client" {
  for_each      = var.lambdas_client_post
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = join("-", ["pichincha", each.value.name, var.environment])
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.pichincha_apigw.execution_arn}/*/*"
  depends_on = [
    aws_lambda_function.lambda_functions_client
  ]
}
### APIGW
resource "aws_api_gateway_rest_api" "pichincha_apigw" {
  name = "${var.api-gateway-name-client}-${var.environment}"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "pichincha_resource" {
  for_each    = var.lambdas_client_post
  rest_api_id = aws_api_gateway_rest_api.pichincha_apigw.id
  parent_id   = aws_api_gateway_rest_api.pichincha_apigw.root_resource_id
  path_part   = each.value.path
}

resource "aws_api_gateway_method" "pichincha_method" {
  for_each         = aws_api_gateway_resource.pichincha_resource
  rest_api_id      = aws_api_gateway_rest_api.pichincha_apigw.id
  resource_id      = each.value.id
  http_method      = "POST"
  authorization    = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.apigw_authorizer.id
  api_key_required = true
}

resource "aws_api_gateway_method" "method_cors_pichincha" {
  for_each      = aws_api_gateway_resource.pichincha_resource
  rest_api_id   = aws_api_gateway_rest_api.pichincha_apigw.id
  resource_id   = each.value.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "pichincha_integration" {
  for_each                = aws_api_gateway_method.pichincha_method
  rest_api_id             = each.value.rest_api_id
  resource_id             = each.value.resource_id
  http_method             = each.value.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = aws_lambda_function.lambda_functions_client[each.key].invoke_arn
}

resource "aws_api_gateway_integration" "integration_cors_backoffice" {
  for_each    = aws_api_gateway_method.method_cors_pichincha
  rest_api_id = each.value.rest_api_id
  resource_id = each.value.resource_id
  http_method = each.value.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = <<EOF
{
      "statusCode": 200
}
EOF
  }
  depends_on = [aws_api_gateway_method.method_cors_pichincha]
}

resource "aws_api_gateway_method_response" "method_response_client" {
  for_each    = aws_api_gateway_method.pichincha_method
  rest_api_id = each.value.rest_api_id
  resource_id = each.value.resource_id
  http_method = each.value.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method_response" "method_cors_pichincha" {
  for_each    = aws_api_gateway_method.method_cors_pichincha
  rest_api_id = each.value.rest_api_id
  resource_id = each.value.resource_id
  http_method = each.value.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
  depends_on = [aws_api_gateway_method.method_cors_pichincha]
}

resource "aws_api_gateway_integration_response" "integration_response_client" {
  for_each    = aws_api_gateway_method_response.method_response_client
  rest_api_id = each.value.rest_api_id
  resource_id = each.value.resource_id
  http_method = each.value.http_method
  status_code = each.value.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
  depends_on = [
    aws_api_gateway_rest_api.pichincha_apigw,
    aws_api_gateway_integration.pichincha_integration
  ]
}

resource "aws_api_gateway_integration_response" "integration_cors_response_backoffice" {
  for_each    = aws_api_gateway_method_response.method_cors_pichincha
  rest_api_id = each.value.rest_api_id
  resource_id = each.value.resource_id
  http_method = each.value.http_method
  status_code = each.value.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  depends_on = [aws_api_gateway_method_response.method_cors_pichincha]
}

resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_rest_api.pichincha_apigw,
    aws_api_gateway_integration.pichincha_integration,
    aws_api_gateway_integration.integration_cors_backoffice

]
  rest_api_id       = aws_api_gateway_rest_api.pichincha_apigw.id
  stage_name        = var.stage_name
  stage_description = "Deployed at ${var.stage_deployed_at}"
}

####
resource "aws_api_gateway_api_key" "pichincha_apikey" {
  name = "pichincha-apikey-${var.environment}"
  value =local.pichincha_apikey.apitoken
}

resource "aws_api_gateway_usage_plan" "pichincha_api_usage_plan" {
  name = "pichincha-usage-plan-${var.environment}"

  api_stages {
    api_id = "${aws_api_gateway_rest_api.pichincha_apigw.id}"
    stage  = "${aws_api_gateway_deployment.api_deployment.stage_name}"
  }
}

resource "aws_api_gateway_usage_plan_key" "pichincha_api_usage_plan_key" {
  key_id        = "${aws_api_gateway_api_key.pichincha_apikey.id}"
  key_type      = "API_KEY"
  usage_plan_id = "${aws_api_gateway_usage_plan.pichincha_api_usage_plan.id}"
}

#### Authorizer
resource "aws_api_gateway_authorizer" "apigw_authorizer" {
  name                   = "apigw_authorizer-${var.environment}"
  rest_api_id            = aws_api_gateway_rest_api.pichincha_apigw.id
  authorizer_uri         = aws_lambda_function.pichincha_lambdas_function_authorizer.invoke_arn
  authorizer_credentials = aws_iam_role.invocation_authorizer_role.arn
  type = "REQUEST"
  identity_source = "method.request.header.authorizationToken"
}

### Lambda authorizer
resource "aws_lambda_function" "pichincha_lambdas_function_authorizer" {
  filename      = "./lambda/authorizer.zip"
  function_name = "pichincha-authorizer-${var.environment}"
  role          = aws_iam_role.pichincha_lambdas.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"

}

resource "aws_iam_role" "invocation_authorizer_role" {
  name = "invocation_authorizer_role"
  path = "/"

  assume_role_policy = <<EOF
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

resource "aws_iam_role_policy" "invocation_authorizer_policy" {
  name = "invocation_authorizer_policy"
  role = aws_iam_role.invocation_authorizer_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "lambda:InvokeFunction",
      "Effect": "Allow",
      "Resource": "${aws_lambda_function.pichincha_lambdas_function_authorizer.arn}"
    }
  ]
}
EOF
}