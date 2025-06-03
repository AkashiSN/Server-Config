resource "aws_lightsail_key_pair" "main" {
  name = "${var.project}_key"
}
