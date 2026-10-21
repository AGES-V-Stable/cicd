mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-2a", "us-east-2b"]
    }
  }
}

run "network_keeps_database_private" {
  command = plan

  module {
    source = "./modules/network"
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
      aws_vpc_security_group_ingress_rule.runner_to_database.cidr_ipv4 == "10.100.0.10/32"
    )
    error_message = "The database must use two private subnets and accept only the specified connected runner CIDR."
  }
}

run "database_is_private_and_has_requested_retention" {
  command = plan

  module {
    source = "./modules/database"
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
    source = "./modules/api"
  }

  variables {
    name                   = "vstable-test"
    image_uri              = "000000000000.dkr.ecr.us-east-2.amazonaws.com/vstable-test-backend@sha256:0000000000000000000000000000000000000000000000000000000000000000"
    private_subnet_ids     = ["subnet-private-a", "subnet-private-b"]
    lambda_sg_id           = "sg-lambda"
    proxy_sg_id            = "sg-proxy"
    db_instance_identifier = "vstable-test-postgres"
    db_name                = "vstable"
    app_db_username        = "vstable_app"
    app_db_password        = "example-only-not-a-secret"
    jwt_secret             = join("", [for i in range(64) : "x"])
    provider_secrets       = {}
    app_password_version   = 1
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
      aws_lambda_function.backend.environment[0].variables.DB_SCHEMA == "vstable"
    )
    error_message = "Lambda must use the image runtime, x86_64, and the existing Spring profile and DB contract."
  }

  assert {
    condition = (
      aws_apigatewayv2_route.default.route_key == "$default" &&
      aws_apigatewayv2_stage.default.name == "$default" &&
      aws_apigatewayv2_integration.lambda.payload_format_version == "2.0" &&
      aws_db_proxy.backend.require_tls
    )
    error_message = "HTTP API must preserve unprefixed routes and the database proxy must require TLS."
  }
}
