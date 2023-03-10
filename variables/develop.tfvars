region="us-east-1"
environment="develop"	
stage_name="develop"
api-gateway-name-client="pichincha_apigw-client"
image_uri_base="ecr_imagen_base"
lambdas_client_post = {
    devops = {
      name  = "devops"
      path = "devops"
    }
}
