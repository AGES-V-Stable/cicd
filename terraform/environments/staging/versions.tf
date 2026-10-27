terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"

  default_tags {
    tags = {
      Application = "vstable-backend"
      Deployment  = "vstable-staging"
      ManagedBy   = "terraform"
    }
  }
}

ephemeral "aws_secretsmanager_secret_version" "rds_master" {
  secret_id = module.database.master_secret_arn
}
