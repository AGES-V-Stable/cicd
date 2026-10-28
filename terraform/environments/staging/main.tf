locals {
  deployment_name = "vstable-staging"
}

module "network" {
  source = "../../modules/network"

  name        = local.deployment_name
  vpc_cidr    = var.vpc_cidr
  runner_cidr = var.runner_cidr
}

module "database" {
  source = "../../modules/database"

  name               = local.deployment_name
  db_name            = var.db_name
  private_subnet_ids = module.network.private_subnet_ids
  database_sg_id     = module.network.database_sg_id
}

module "registry" {
  source = "../../modules/registry"

  name = local.deployment_name
}

module "frontend" {
  source = "../../modules/frontend"

  name = local.deployment_name
}

module "frontend_deploy_role" {
  source = "../../modules/frontend_deploy_role"

  name                = local.deployment_name
  github_oidc_subject = var.github_oidc_subject
  github_ref_pattern  = "refs/heads/main"
  bucket_arn          = module.frontend.bucket_arn
  distribution_arn    = module.frontend.distribution_arn
}

module "backend_deploy_role" {
  source = "../../modules/backend_deploy_role"

  name                 = local.deployment_name
  github_oidc_subject  = var.backend_github_oidc_subject
  github_ref_pattern   = "refs/heads/main"
  ecr_repository_arn   = module.registry.repository_arn
  lambda_function_arns = [module.api.backend_lambda_arn]
}

module "api" {
  source = "../../modules/api"

  name                   = local.deployment_name
  image_uri              = "${module.registry.repository_url}@${var.image_digest}"
  private_subnet_ids     = module.network.private_subnet_ids
  lambda_sg_id           = module.network.lambda_sg_id
  db_host                = module.database.address
  db_name                = var.db_name
  db_username            = module.database.master_username
  db_password            = jsondecode(ephemeral.aws_secretsmanager_secret_version.rds_master.secret_string).password
  jwt_secret             = var.jwt_secret
  provider_secrets       = var.provider_secrets
  app_config_version     = var.app_config_version
  cors_allowed_origins   = module.frontend.url
  avenia_base_url        = var.avenia_base_url
  blindpay_base_url      = var.blindpay_base_url
  avenia_webhook_url     = var.avenia_webhook_url
  http_connect_timeout   = var.http_connect_timeout
  http_read_timeout      = var.http_read_timeout
  quote_provider_timeout = var.quote_provider_timeout

  depends_on = [module.network, module.registry]
}
