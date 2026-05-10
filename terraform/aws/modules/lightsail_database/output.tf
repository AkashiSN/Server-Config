output "endpoint" {
  value = aws_lightsail_database.this.master_endpoint_address
}

output "port" {
  value = aws_lightsail_database.this.master_endpoint_port
}

output "ca_certificate_identifier" {
  value = aws_lightsail_database.this.ca_certificate_identifier
}

output "engine" {
  value = aws_lightsail_database.this.engine
}

output "engine_version" {
  value = aws_lightsail_database.this.engine_version
}

output "arn" {
  value = aws_lightsail_database.this.arn
}
