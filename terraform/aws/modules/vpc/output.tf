output "vpc_id" {
  value = aws_vpc.main.id
}

output "route_table_main_id" {
  value = aws_vpc.main.main_route_table_id
}

output "route_table_private_a_id" {
  value = aws_route_table.private_a.id
}

output "route_table_private_c_id" {
  value = aws_route_table.private_c.id
}

output "subnet_private_a_id" {
  value = aws_subnet.private_a.id
}

output "subnet_private_c_id" {
  value = aws_subnet.private_c.id
}
