module "network" {
  source = "./modules/network"

  name        = var.deployment_name
  vpc_cidr    = var.vpc_cidr
  runner_cidr = var.runner_cidr
}

module "database" {
  source = "./modules/database"

  name               = var.deployment_name
  db_name            = var.db_name
  private_subnet_ids = module.network.private_subnet_ids
  database_sg_id     = module.network.database_sg_id
}

module "database_role" {
  source = "./modules/database_role"

  providers = {
    postgresql = postgresql
  }

  db_name              = var.db_name
  app_username         = var.app_db_username
  app_password         = var.app_db_password
  app_password_version = var.app_password_version

  depends_on = [module.database]
}

module "registry" {
  source = "./modules/registry"

  name = var.deployment_name
}

module "api" {
  source = "./modules/api"

  name                   = var.deployment_name
  image_uri              = "${module.registry.repository_url}@${var.image_digest}"
  private_subnet_ids     = module.network.private_subnet_ids
  lambda_sg_id           = module.network.lambda_sg_id
  proxy_sg_id            = module.network.proxy_sg_id
  db_instance_identifier = module.database.identifier
  db_name                = var.db_name
  app_db_username        = var.app_db_username
  app_db_password        = var.app_db_password
  jwt_secret             = var.jwt_secret
  provider_secrets       = var.provider_secrets
  app_password_version   = var.app_password_version
  app_config_version     = var.app_config_version
  cors_allowed_origins   = var.cors_allowed_origins
  avenia_base_url        = var.avenia_base_url
  blindpay_base_url      = var.blindpay_base_url
  avenia_webhook_url     = var.avenia_webhook_url
  http_connect_timeout   = var.http_connect_timeout
  http_read_timeout      = var.http_read_timeout
  quote_provider_timeout = var.quote_provider_timeout

  depends_on = [module.database_role, module.registry]
}
