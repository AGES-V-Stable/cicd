output "private_subnet_ids" {
  value = [for key in sort(keys(aws_subnet.private)) : aws_subnet.private[key].id]
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_route_table_id" {
  value = aws_route_table.private.id
}

output "lambda_sg_id" {
  value = aws_security_group.lambda.id
}

output "database_sg_id" {
  value = aws_security_group.database.id
}
