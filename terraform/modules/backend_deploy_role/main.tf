data "aws_caller_identity" "current" {}

resource "aws_iam_role" "backend_deploy" {
  name = "${var.name}-backend-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = var.github_oidc_subject
        }
        StringLike = {
          "token.actions.githubusercontent.com:ref" = var.github_ref_pattern
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "backend_deploy" {
  name = "backend-deploy"
  role = aws_iam_role.backend_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "ecr:GetAuthorizationToken",
          "ecr-public:GetAuthorizationToken",
          "sts:GetServiceBearerToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        Resource = var.ecr_repository_arn
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:GetFunctionConfiguration",
          "lambda:InvokeFunction",
          "lambda:UpdateFunctionCode"
        ]
        Resource = var.lambda_function_arns
      }
    ]
  })
}
