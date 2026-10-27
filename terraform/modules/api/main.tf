resource "aws_secretsmanager_secret" "app" {
  name                    = "${var.name}/backend/app-config"
  description             = "Runtime configuration for the backend Lambda"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id
  secret_string_wo = jsonencode(merge({
    DB_USERNAME = var.db_username
    DB_PASSWORD = var.db_password
    JWT_SECRET  = var.jwt_secret
  }, var.provider_secrets))
  # Force a new version when migrating from the former application DB role.
  secret_string_wo_version = var.app_config_version + 1
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.name}-backend"
  retention_in_days = 14
}

resource "aws_iam_role" "lambda" {
  name = "${var.name}-backend-lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_secret" {
  name = "app-config-secret-read"
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = aws_secretsmanager_secret.app.arn
    }]
  })
}

resource "aws_lambda_function" "backend" {
  function_name = "${var.name}-backend"
  package_type  = "Image"
  image_uri     = var.image_uri
  architectures = ["x86_64"]
  role          = aws_iam_role.lambda.arn
  memory_size   = 2048
  timeout       = 30

  lifecycle {
    precondition {
      condition     = !endswith(var.image_uri, "sha256:0000000000000000000000000000000000000000000000000000000000000000")
      error_message = "The Lambda image digest is the bootstrap placeholder. Push a Lambda-compatible image to ECR and set image_digest to its real sha256 digest before a full apply."
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_sg_id]
  }

  environment {
    variables = {
      SPRING_PROFILES_ACTIVE      = "lambda"
      APP_CONFIG_SECRET_ARN       = aws_secretsmanager_secret_version.app.secret_arn
      DB_HOST                     = var.db_host
      DB_PORT                     = "5432"
      DB_SCHEMA                   = var.db_name
      CORS_ALLOWED_ORIGINS        = var.cors_allowed_origins
      AVENIA_BASE_URL             = var.avenia_base_url
      BLINDPAY_BASE_URL           = var.blindpay_base_url
      AVENIA_WEBHOOK_URL          = var.avenia_webhook_url
      HTTP_CLIENT_CONNECT_TIMEOUT = var.http_connect_timeout
      HTTP_CLIENT_READ_TIMEOUT    = var.http_read_timeout
      QUOTE_PROVIDER_TIMEOUT      = var.quote_provider_timeout
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_vpc_logs,
    aws_iam_role_policy.lambda_secret,
    aws_cloudwatch_log_group.lambda
  ]

  tags = { Name = "${var.name}-backend-lambda" }
}

resource "aws_apigatewayv2_api" "backend" {
  name          = "${var.name}-backend-http"
  protocol_type = "HTTP"

  tags = { Name = "${var.name}-backend-http" }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.backend.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.backend.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.backend.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.backend.id
  name        = "$default"
  auto_deploy = true

  depends_on = [aws_apigatewayv2_route.default]
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backend.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.backend.execution_arn}/*"
}
