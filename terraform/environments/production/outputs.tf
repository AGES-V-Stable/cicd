output "ecr_repository_url" {
  description = "Push the Lambda image to this ECR repository."
  value       = module.registry.repository_url
}

output "rds_endpoint" {
  description = "Private direct RDS endpoint used by Lambda."
  value       = module.database.address
}

output "vpc_id" {
  description = "New VPC ID for connecting the private Terraform runner network."
  value       = module.network.vpc_id
}

output "private_route_table_id" {
  description = "Private route table ID; the connected network needs a route to the runner CIDR."
  value       = module.network.private_route_table_id
}

output "api_url" {
  description = "Public API Gateway URL after the Lambda API module is enabled."
  value       = module.api.api_url
}

output "frontend_url" {
  value = module.frontend.url
}

output "frontend_bucket_name" {
  value = module.frontend.bucket_name
}

output "frontend_distribution_id" {
  value = module.frontend.distribution_id
}

output "frontend_deploy_role_arn" {
  value = module.frontend_deploy_role.role_arn
}

output "app_secret_arn" {
  description = "Application configuration secret ARN; no secret values are output."
  value       = module.api.app_secret_arn
}
