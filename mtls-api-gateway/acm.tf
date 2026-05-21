# =============================================================================
# ACM Certificate para el Custom Domain del API Gateway
# Se solicita en la misma región donde vive el API (REGIONAL endpoint).
# La validación se hace por DNS usando Route 53.
# =============================================================================

resource "aws_acm_certificate" "api_domain" {
  domain_name               = var.custom_domain
  subject_alternative_names = ["*.${join(".", slice(split(".", var.custom_domain), 1, length(split(".", var.custom_domain))))}" ]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-cert"
  }
}

# Crear los registros DNS de validación en Route 53
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.api_domain.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  zone_id         = var.hosted_zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
}

# Esperar a que ACM valide el certificado
resource "aws_acm_certificate_validation" "api_domain" {
  certificate_arn         = aws_acm_certificate.api_domain.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
