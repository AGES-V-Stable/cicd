locals {
  internal_jobs = toset(["migration", "seed"])
}

resource "aws_cloudwatch_log_group" "internal_job" {
  for_each = local.internal_jobs

  name              = "/aws/lambda/${var.name}-${each.key}"
  retention_in_days = 14
}

resource "aws_iam_role" "internal_job" {
  for_each = local.internal_jobs

  name               = "${var.name}-${each.key}-lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "internal_job_vpc_logs" {
  for_each = local.internal_jobs

  role       = aws_iam_role.internal_job[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "internal_job_secret" {
  for_each = local.internal_jobs

  name   = "app-config-secret-read"
  role   = aws_iam_role.internal_job[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = aws_secretsmanager_secret.app.arn
    }]
  })
}

resource "aws_lambda_function" "internal_job" {
  for_each = local.internal_jobs

  function_name                   = "${var.name}-${each.key}"
  package_type                    = "Image"
  image_uri                       = var.image_uri
  architectures                   = ["x86_64"]
  role                            = aws_iam_role.internal_job[each.key].arn
  memory_size                     = 2048
  timeout                         = 900
  reserved_concurrent_executions = 1

  lifecycle {
    precondition {
      condition     = !endswith(var.image_uri, "sha256:0000000000000000000000000000000000000000000000000000000000000000")
      error_message = "Push a Lambda-compatible image to ECR and set image_digest to its real sha256 digest before creating the internal jobs."
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_sg_id]
  }

  environment {
    variables = {
      SPRING_PROFILES_ACTIVE           = "lambda,${each.key}"
      AWS_LWA_PASS_THROUGH_PATH        = "/events"
      AWS_LWA_ERROR_STATUS_CODES       = "500-599"
      TRANSFERS_RECONCILIATION_ENABLED = "false"
      APP_CONFIG_SECRET_ARN            = aws_secretsmanager_secret_version.app.secret_arn
      DB_HOST                          = var.db_host
      DB_PORT                          = "5432"
      DB_SCHEMA                        = var.db_name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.internal_job_vpc_logs,
    aws_iam_role_policy.internal_job_secret,
    aws_cloudwatch_log_group.internal_job
  ]

  tags = { Name = "${var.name}-${each.key}-lambda" }
}
