variable "db_name" {
  type = string
}

variable "app_username" {
  type = string
}

variable "app_password" {
  type      = string
  sensitive = true
  ephemeral = true
}

variable "app_password_version" {
  type = number
}
