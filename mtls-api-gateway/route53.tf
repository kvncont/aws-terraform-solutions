# =============================================================================
# Route 53 — Registro para el Custom Domain del API Gateway
# Apunta el dominio al API Gateway custom domain name regional.
# Se usa un alias A record (no CNAME) para mayor compatibilidad.
# =============================================================================

# Obtener el Hosted Zone por ID
data "aws_route53_zone" "internal" {
  zone_id = var.hosted_zone_id
}

# Alias A record: custom_domain → API Gateway regional domain
resource "aws_route53_record" "api_domain" {
  zone_id = data.aws_route53_zone.internal.zone_id
  name    = var.custom_domain
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.main.regional_domain_name
    zone_id                = aws_api_gateway_domain_name.main.regional_zone_id
    evaluate_target_health = false
  }
}
