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

# A (alias): ${var.prefix_custom_domain}.api.internal.example.com → ALB interno (punto de entrada con mTLS)
# El nombre debe coincidir con aws_api_gateway_domain_name.main.domain_name para que
# API Gateway pueda hacer el routing por Host header.
resource "aws_route53_record" "api_domain" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "${var.prefix_custom_domain}.${var.custom_domain}"
  type    = "A"

  alias {
    name                   = aws_lb.internal.dns_name
    zone_id                = aws_lb.internal.zone_id
    evaluate_target_health = true
  }
}

# OPCIONAL — CNAME al ALB (alternativa al registro A con alias de arriba)
# Usar si se prefiere TTL explícito en lugar de alias Route53.
# resource "aws_route53_record" "api_domain" {
#   zone_id = aws_route53_zone.internal.zone_id
#   name    = "${var.prefix_custom_domain}.${var.custom_domain}"
#   type    = "CNAME"
#   ttl     = 300
#   records = [aws_lb.internal.dns_name]
# }
