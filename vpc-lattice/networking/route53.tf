resource "aws_route53_zone" "private" {
  name = "example.com"

  vpc {
    vpc_id = aws_vpc.networking.id
  }

  lifecycle {
    ignore_changes = [vpc]
  }
}
