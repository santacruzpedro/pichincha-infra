region="us-east-1"
environment="develop"	
stage_name="develop"
api-gateway-name-client="pichincha_apigw-client"
bucket_client_name="ventiu-files-client"
image_uri_base="724404050210.dkr.ecr.us-east-1.amazonaws.com/s4bps-business-central:businesscentral-develop-499f352-20221222-002724722"
lambdas_client_post = {
    devops = {
      name  = "devops"
      path = "devops"
    }
}