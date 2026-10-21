output "address" {
  value = aws_db_instance.main.address
}

output "identifier" {
  value = aws_db_instance.main.identifier
}

output "master_username" {
  value = aws_db_instance.main.username
}

output "master_secret_arn" {
  value = aws_db_instance.main.master_user_secret[0].secret_arn
}
