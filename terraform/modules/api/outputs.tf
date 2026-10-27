output "api_url" {
  value = aws_apigatewayv2_stage.default.invoke_url
}

output "app_secret_arn" {
  value = aws_secretsmanager_secret.app.arn
}
