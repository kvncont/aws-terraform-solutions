resource "aws_acm_certificate" "producer" {
  private_key      = file("${path.module}/certs/server.key")
  certificate_body = file("${path.module}/certs/server.crt")

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "producer-cert"
  }
}