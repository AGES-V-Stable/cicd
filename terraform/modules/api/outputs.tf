output "api_url" {
  value = aws_apigatewayv2_stage.default.invoke_url
}

output "app_secret_arn" {
  value = aws_secretsmanager_secret.app.arn
}

output "backend_lambda_arn" {
  value = aws_lambda_function.backend.arn
}

output "migration_lambda_arn" {
  value = aws_lambda_function.internal_job["migration"].arn
}

output "migration_lambda_name" {
  value = aws_lambda_function.internal_job["migration"].function_name
}

output "seed_lambda_arn" {
  value = aws_lambda_function.internal_job["seed"].arn
}

output "seed_lambda_name" {
  value = aws_lambda_function.internal_job["seed"].function_name
}
