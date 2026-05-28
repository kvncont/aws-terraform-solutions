# =============================================================================
# ACM Certificate — Certificado importado desde certs/ (generado localmente)
#
# COSTO: $0 — ACM no cobra por almacenar certificados importados.
#
# PREREQUISITO: ejecutar antes de terraform apply:
#   cd certs && bash generate_certs.sh api.internal.example.com
#
# NOTA: usar un cert importado con aws_api_gateway_domain_name requiere
# ownership_verification_certificate_arn (cert ACM público). Ver variables.tf.
# =============================================================================

resource "aws_acm_certificate" "api_domain" {
  private_key      = file("${path.module}/certs/server.key")
  certificate_body = file("${path.module}/certs/server.crt")
  # certificate_chain omitido intencionalmente: server-ca.crt es la CA raíz
  # auto-firmada. Incluirla en la cadena presentada al cliente causa
  # OpenSSL error 19 en versiones 3.x (self-signed certificate in certificate chain).
  # Los clientes deben tener server-ca.crt en su trust store local (--cacert).

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-cert"
  }
}

# =============================================================================
# ACM Private CA — Autoridad Certificadora Privada (DESACTIVADA)
#
# COSTO ESTIMADO:
#   - CA activa:             ~$400 USD/mes (corre desde que se crea)
#   - Certificados emitidos: $0.75 por cert (primeros 1,000/mes)
#   - Retención al destruir: 7 días mínimo → ~$93 USD adicionales
#
# Descomentar solo si se necesita una CA gestionada por AWS.
# =============================================================================

# resource "aws_acmpca_certificate_authority" "root" { ... }
# resource "aws_acmpca_certificate" "root_cert" { ... }
# resource "aws_acmpca_certificate_authority_certificate" "root" { ... }
# resource "aws_acmpca_permission" "acm" { ... }
