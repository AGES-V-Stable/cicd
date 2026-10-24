variable "vpc_cidr" {
  description = "A free /16 IPv4 range reachable from the Terraform runner's connected network."
  type        = string
  default     = "10.43.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr)) && endswith(var.vpc_cidr, "/16")
    error_message = "vpc_cidr must be an IPv4 /16 CIDR."
  }
}

variable "runner_cidr" {
  description = "IPv4 source CIDR routed to the private VPC from the Terraform runner. Keep this narrow."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.runner_cidr)) && var.runner_cidr != "0.0.0.0/0"
    error_message = "runner_cidr must be a restricted IPv4 CIDR."
  }
}

variable "rds_ca_bundle_path" {
  description = "Absolute path on the Terraform runner to the trusted RDS CA PEM bundle."
  type        = string

  validation {
    condition     = length(trimspace(var.rds_ca_bundle_path)) > 0
    error_message = "rds_ca_bundle_path is required."
  }
}

variable "db_name" {
  description = "Initial PostgreSQL database name used by the application."
  type        = string
  default     = "vstable"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,62}$", var.db_name))
    error_message = "db_name must be a lowercase PostgreSQL identifier of at most 63 characters."
  }
}

variable "app_db_username" {
  description = "Dedicated PostgreSQL role used by the application and RDS Proxy."
  type        = string
  default     = "vstable_app"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,62}$", var.app_db_username))
    error_message = "app_db_username must be a lowercase PostgreSQL identifier of at most 63 characters."
  }
}

variable "app_db_password" {
  description = "Application database password. Supply through a protected TF_VAR environment variable."
  type        = string
  sensitive   = true
  ephemeral   = true

  validation {
    condition     = length(var.app_db_password) >= 16
    error_message = "app_db_password must contain at least 16 characters."
  }
}

variable "jwt_secret" {
  description = "JWT HS512 key. Supply through a protected TF_VAR environment variable."
  type        = string
  sensitive   = true
  ephemeral   = true

  validation {
    condition     = length(var.jwt_secret) >= 64
    error_message = "jwt_secret must contain at least 64 characters."
  }
}

variable "provider_secrets" {
  description = "Optional Avenia and BlindPay secret values using the JSON keys documented in README."
  type        = map(string)
  sensitive   = true
  ephemeral   = true
  default     = {}

  validation {
    condition = alltrue([
      for key in keys(var.provider_secrets) : contains([
        "AVENIA_API_KEY", "AVENIA_PRIVATE_KEY", "AVENIA_EMAIL", "AVENIA_PASSWORD",
        "BLINDPAY_API_KEY", "BLINDPAY_INSTANCE_ID", "BLINDPAY_WEBHOOK_SECRET"
      ], key)
    ])
    error_message = "provider_secrets contains an unsupported key."
  }
}

variable "app_password_version" {
  description = "Increment when app_db_password changes; updates the PostgreSQL role and proxy secret."
  type        = number
  default     = 1

  validation {
    condition     = var.app_password_version >= 1 && floor(var.app_password_version) == var.app_password_version
    error_message = "app_password_version must be a positive integer."
  }
}

variable "app_config_version" {
  description = "Increment when any value in the Lambda application JSON secret changes."
  type        = number
  default     = 1

  validation {
    condition     = var.app_config_version >= 1 && floor(var.app_config_version) == var.app_config_version
    error_message = "app_config_version must be a positive integer."
  }
}

variable "image_digest" {
  description = "ECR image digest (sha256:...). Use a placeholder only for the targeted bootstrap apply."
  type        = string

  validation {
    condition     = can(regex("^sha256:[0-9a-f]{64}$", var.image_digest))
    error_message = "image_digest must be a sha256 digest."
  }
}

variable "github_oidc_subject" {
  description = "Exact GitHub OIDC subject for the frontend repository's production environment."
  type        = string
  default     = "repo:AGES-V-Stable/frontend:environment:production"
}

variable "avenia_base_url" {
  description = "Avenia API base URL."
  type        = string
  default     = "https://api.sandbox.avenia.io:10952"
}

variable "blindpay_base_url" {
  description = "BlindPay API base URL."
  type        = string
  default     = "https://api.blindpay.com"
}

variable "avenia_webhook_url" {
  description = "Public callback URL sent to Avenia, if that integration is enabled."
  type        = string
  default     = ""
}

variable "http_connect_timeout" {
  description = "Spring HTTP client connection timeout."
  type        = string
  default     = "5s"
}

variable "http_read_timeout" {
  description = "Spring HTTP client read timeout."
  type        = string
  default     = "30s"
}

variable "quote_provider_timeout" {
  description = "Quote provider timeout."
  type        = string
  default     = "10s"
}
