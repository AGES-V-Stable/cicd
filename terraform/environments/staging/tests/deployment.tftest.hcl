mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "us-east-2"
    }
  }

  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-2a", "us-east-2b"]
    }
  }
}

run "network_keeps_database_private" {
  command = plan

  module {
    source = "../../modules/network"
  }

  variables {
    name        = "vstable-test"
    vpc_cidr    = "10.42.0.0/16"
    runner_cidr = "10.100.0.10/32"
  }

  assert {
    condition = (
      length(aws_subnet.private) == 2 &&
      aws_subnet.private["0"].cidr_block == "10.42.2.0/24" &&
      aws_subnet.private["1"].cidr_block == "10.42.3.0/24" &&
      !aws_subnet.private["0"].map_public_ip_on_launch &&
      aws_vpc_security_group_ingress_rule.runner_to_database.cidr_ipv4 == "10.100.0.10/32" &&
      aws_vpc_security_group_ingress_rule.lambda_to_database.referenced_security_group_id == aws_security_group.lambda.id &&
      aws_vpc_security_group_ingress_rule.lambda_to_database.from_port == 5432
    )
    error_message = "The database must use two private subnets and accept PostgreSQL from Lambda and the specified runner CIDR."
  }
}

run "database_is_private_and_has_requested_retention" {
  command = plan

  module {
    source = "../../modules/database"
  }

  variables {
    name               = "vstable-test"
    db_name            = "vstable"
    private_subnet_ids = ["subnet-private-a", "subnet-private-b"]
    database_sg_id     = "sg-database"
  }

  assert {
    condition = (
      aws_db_instance.main.instance_class == "db.t4g.micro" &&
      aws_db_instance.main.engine_version == "16" &&
      aws_db_instance.main.allocated_storage == 20 &&
      aws_db_instance.main.storage_type == "gp3" &&
      aws_db_instance.main.storage_encrypted
    )
    error_message = "RDS must use the requested encrypted PostgreSQL 16 micro instance."
  }

  assert {
    condition = (
      !aws_db_instance.main.publicly_accessible &&
      !aws_db_instance.main.multi_az &&
      aws_db_instance.main.backup_retention_period == 0 &&
      aws_db_instance.main.deletion_protection &&
      aws_db_instance.main.skip_final_snapshot
    )
    error_message = "RDS must be private, Single-AZ, protected from deletion, and have no Terraform-managed backup or final snapshot."
  }
}

run "lambda_and_gateway_keep_existing_http_contract" {
  command = plan

  module {
    source = "../../modules/api"
  }

  variables {
    name                   = "vstable-test"
    image_uri              = "000000000000.dkr.ecr.us-east-2.amazonaws.com/vstable-test-backend@sha256:1111111111111111111111111111111111111111111111111111111111111111"
    private_subnet_ids     = ["subnet-private-a", "subnet-private-b"]
    lambda_sg_id           = "sg-lambda"
    db_host                = "vstable-test-postgres.example.rds.amazonaws.com"
    db_name                = "vstable"
    db_username            = "vstable_admin"
    db_password            = "example-only-not-a-secret"
    jwt_secret             = join("", [for i in range(64) : "x"])
    provider_secrets       = {}
    app_config_version     = 1
    cors_allowed_origins   = "https://app.example.com"
    avenia_base_url        = "https://avenia.example.com"
    blindpay_base_url      = "https://blindpay.example.com"
    avenia_webhook_url     = "https://api.example.com/webhook"
    http_connect_timeout   = "5s"
    http_read_timeout      = "30s"
    quote_provider_timeout = "10s"
  }

  assert {
    condition = (
      aws_lambda_function.backend.package_type == "Image" &&
      aws_lambda_function.backend.architectures[0] == "x86_64" &&
      aws_lambda_function.backend.memory_size == 2048 &&
      aws_lambda_function.backend.timeout == 30 &&
      aws_lambda_function.backend.environment[0].variables.SPRING_PROFILES_ACTIVE == "lambda" &&
      aws_lambda_function.backend.environment[0].variables.DB_HOST == "vstable-test-postgres.example.rds.amazonaws.com" &&
      aws_lambda_function.backend.environment[0].variables.DB_SCHEMA == "vstable" &&
      aws_secretsmanager_secret_version.app.secret_string_wo_version == 2
    )
    error_message = "Lambda must use the image runtime, x86_64, and the direct RDS connection contract."
  }

  assert {
    condition = (
      aws_apigatewayv2_route.default.route_key == "$default" &&
      aws_apigatewayv2_stage.default.name == "$default" &&
      aws_apigatewayv2_integration.lambda.payload_format_version == "2.0"
    )
    error_message = "HTTP API must preserve unprefixed routes."
  }
}

run "frontend_is_private_and_served_over_https" {
  command = plan

  module {
    source = "../../modules/frontend"
  }

  variables {
    name = "vstable-test"
  }

  assert {
    condition = (
      aws_s3_bucket_public_access_block.frontend.block_public_policy &&
      aws_s3_bucket_public_access_block.frontend.restrict_public_buckets &&
      aws_cloudfront_origin_access_control.frontend.signing_behavior == "always" &&
      aws_cloudfront_distribution.frontend.default_cache_behavior[0].viewer_protocol_policy == "redirect-to-https" &&
      aws_cloudfront_function.spa_routes.publish
    )
    error_message = "The React bucket must be private and served through signed HTTPS CloudFront requests."
  }
}

run "production_deploy_role_accepts_only_release_refs" {
  command = plan

  module {
    source = "../../modules/frontend_deploy_role"
  }

  variables {
    name                = "vstable-production"
    github_oidc_subject = "repo:AGES-V-Stable/frontend:environment:production"
    github_ref_pattern  = "refs/tags/*"
    bucket_arn          = "arn:aws:s3:::vstable-production-test-frontend"
    distribution_arn    = "arn:aws:cloudfront::123456789012:distribution/EXAMPLE"
  }

  assert {
    condition = (
      jsondecode(aws_iam_role.frontend_deploy.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == "repo:AGES-V-Stable/frontend:environment:production" &&
      jsondecode(aws_iam_role.frontend_deploy.assume_role_policy).Statement[0].Condition.StringLike["token.actions.githubusercontent.com:ref"] == "refs/tags/*"
    )
    error_message = "Production deployment trust must be limited to this frontend repository's releases."
  }
}
