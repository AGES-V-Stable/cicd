terraform {
  required_providers {
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.27"
    }
  }
}

resource "postgresql_role" "app" {
  name                = var.app_username
  login               = true
  superuser           = false
  create_database     = false
  create_role         = false
  replication         = false
  password_wo         = var.app_password
  password_wo_version = tostring(var.app_password_version)

  lifecycle {
    prevent_destroy = true
  }
}

resource "postgresql_grant" "database_connect" {
  database    = var.db_name
  role        = postgresql_role.app.name
  object_type = "database"
  privileges  = ["CONNECT"]
}

resource "postgresql_grant" "public_schema" {
  database    = var.db_name
  role        = postgresql_role.app.name
  schema      = "public"
  object_type = "schema"
  privileges  = ["USAGE", "CREATE"]

  depends_on = [postgresql_grant.database_connect]
}
