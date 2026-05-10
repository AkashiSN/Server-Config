resource "aws_lightsail_key_pair" "this" {
  name = "${var.project}_${var.purpose}_key"
}
