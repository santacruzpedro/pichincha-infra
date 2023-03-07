resource "aws_ecr_repository" "post" {
  for_each = var.lambdas_client_post
  name     = "pichincha_${each.value.path}"
  image_scanning_configuration {
    scan_on_push = true
  }
  image_tag_mutability = "MUTABLE"
}

resource "aws_ecr_repository_policy" "post" {
  for_each = resource.aws_ecr_repository.post
  repository = each.value.name
  policy = <<EOF
{
  "Statement": [
    {
      "Condition": {
        "StringLike": {
          "aws:sourceArn": "arn:aws:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:*"
        }
      },
      "Action": [
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
        "ecr:SetRepositoryPolicy",
        "ecr:DeleteRepositoryPolicy",
        "ecr:GetRepositoryPolicy"
      ],
      "Principal": {
        "Service": [
          "lambda.amazonaws.com"
        ]
      },
      "Effect": "Allow",
      "Sid": "LambdaECRImageRetrievalPolicy"
    }
  ],
  "Version": "2008-10-17"
}
EOF
}