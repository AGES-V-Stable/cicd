terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.27"
    }
  }
}

provider "aws" {
  region = "us-east-2"

  default_tags {
    tags = {
      Application = "vstable-backend"
      Deployment  = var.deployment_name
      ManagedBy   = "terraform"
    }
  }
}

ephemeral "aws_secretsmanager_secret_version" "rds_master" {
  secret_id = module.database.master_secret_arn
}

provider "postgresql" {
  host             = module.database.address
  port             = 5432
  database         = "postgres"
  username         = module.database.master_username
  password         = jsondecode(ephemeral.aws_secretsmanager_secret_version.rds_master.secret_string).password
  superuser        = false
  sslmode          = "verify-full"
  sslrootcert      = var.rds_ca_bundle_path
  connect_timeout  = 15
  expected_version = "16"
}
