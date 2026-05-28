# =============================================================================
# Route 53 — Private Hosted Zone + Registro para el Custom Domain del API Gateway
# =============================================================================

# Private Hosted Zone — solo resolvible dentro de la VPC
resource "aws_route53_zone" "internal" {
  name    = var.custom_domain
  comment = "Private zone para mTLS API Gateway"

  vpc {
    vpc_id = aws_vpc.main.id
  }

  tags = {
    Name = "${var.project_name}-private-zone"
  }
}

resource "aws_route53_record" "api_domain" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "${var.prefix_custom_domain}.${var.custom_domain}"
  type    = "A"
  alias {
    name                   = aws_vpc_endpoint.apigw.dns_entry[0].dns_name
    zone_id                = aws_vpc_endpoint.apigw.dns_entry[0].hosted_zone_id
    evaluate_target_health = false
  }
}

# OPCIONAL — CNAME al VPC Endpoint (alternativa al registro A con alias de arriba)
# Usar si se prefiere TTL explícito en lugar de alias Route53.
# resource "aws_route53_record" "api_domain" {
#   zone_id = aws_route53_zone.internal.zone_id
#   name    = "${var.prefix_custom_domain}.${var.custom_domain}"
#   type    = "CNAME"
#   ttl     = 300
#   records = [aws_vpc_endpoint.apigw.dns_entry[0].dns_name]
# }
