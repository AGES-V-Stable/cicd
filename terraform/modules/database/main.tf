resource "aws_db_subnet_group" "main" {
  name       = "${var.name}-database"
  subnet_ids = var.private_subnet_ids

  tags = { Name = "${var.name}-database-subnets" }
}

resource "aws_db_instance" "main" {
  identifier                   = "${var.name}-postgres"
  engine                       = "postgres"
  engine_version               = "16"
  instance_class               = "db.t4g.micro"
  allocated_storage            = 20
  storage_type                 = "gp3"
  storage_encrypted            = true
  db_name                      = var.db_name
  username                     = "vstable_admin"
  manage_master_user_password  = true
  port                         = 5432
  db_subnet_group_name         = aws_db_subnet_group.main.name
  vpc_security_group_ids       = [var.database_sg_id]
  publicly_accessible          = false
  multi_az                     = false
  backup_retention_period      = 0
  delete_automated_backups     = true
  deletion_protection          = true
  skip_final_snapshot          = true
  auto_minor_version_upgrade   = true
  performance_insights_enabled = false

  tags = { Name = "${var.name}-postgres" }
}
