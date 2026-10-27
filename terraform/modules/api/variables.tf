variable "name" {
  type = string
}

variable "image_uri" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "lambda_sg_id" {
  type = string
}

variable "db_host" {
  type = string
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
  ephemeral = true
}

variable "jwt_secret" {
  type      = string
  sensitive = true
  ephemeral = true
}

variable "provider_secrets" {
  type      = map(string)
  sensitive = true
  ephemeral = true
}

variable "app_config_version" {
  type = number
}

variable "cors_allowed_origins" {
  type = string
}

variable "avenia_base_url" {
  type = string
}

variable "blindpay_base_url" {
  type = string
}

variable "avenia_webhook_url" {
  type = string
}

variable "http_connect_timeout" {
  type = string
}

variable "http_read_timeout" {
  type = string
}

variable "quote_provider_timeout" {
  type = string
}
