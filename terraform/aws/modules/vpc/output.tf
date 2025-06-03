output "vpc_id" {
  value = aws_vpc.main.id
}

output "vpc_cidr" {
  value = aws_vpc.main.cidr_block
}

output "route_table_main_id" {
  value = aws_vpc.main.main_route_table_id
}

output "route_table_private_a_id" {
  value = aws_route_table.private[0].id
}

output "route_table_private_c_id" {
  value = aws_route_table.private[1].id
}

output "subnet_private_a_id" {
  value = aws_subnet.main[0].id
}

output "subnet_private_c_id" {
  value = aws_subnet.main[1].id
}
