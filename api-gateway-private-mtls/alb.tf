# =============================================================================
# Internal ALB con mTLS — patrón para Private API Gateway
#
# API Gateway PRIVATE no soporta mTLS nativo. La solución es:
#   Cliente → ALB (verifica cert cliente) → VPC Endpoint → API Gateway → Lambda
#
# El ALB termina TLS, verifica el certificado del cliente contra el trust store
# y solo reenvía la request si el cert es válido. El SG del VPC Endpoint
# restringe el acceso exclusivamente al ALB, evitando que alguien lo invoque
# directamente sin pasar por la verificación mTLS.
#
# Ref: https://aws.amazon.com/blogs/compute/consuming-private-amazon-api-gateway-apis-using-mutual-tls/
# =============================================================================

# -----------------------------------------------------------------------------
# Trust Store — CA del cliente (mismo truststore.pem del bucket S3)
# -----------------------------------------------------------------------------
resource "aws_lb_trust_store" "mtls" {
  name                             = "${var.project_name}-trust-store"
  ca_certificates_bundle_s3_bucket = aws_s3_bucket.truststore.bucket
  ca_certificates_bundle_s3_key    = aws_s3_object.truststore_pem.key

  tags = {
    Name = "${var.project_name}-trust-store"
  }
}

# -----------------------------------------------------------------------------
# Target Group — IPs del VPC Endpoint en puerto 443 (HTTPS)
# matcher 200,403: 403 es respuesta esperada sin headers correctos de API GW
# -----------------------------------------------------------------------------
resource "aws_lb_target_group" "vpce_apigw" {
  name        = "${var.project_name}-tg-vpce"
  port        = 443
  protocol    = "HTTPS"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTPS"
    matcher             = "200,403"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-tg-vpce"
  }
}

# Resolver la IP privada de cada ENI del VPC Endpoint
# Se usa el índice de subred como clave del for_each (conocido en plan)
# en lugar del ID de ENI (desconocido hasta después del apply).
# depends_on fuerza la lectura en apply, no en plan.
data "aws_network_interface" "vpce_apigw" {
  for_each = { for idx, s in aws_subnet.private : tostring(idx) => s.id }

  filter {
    name   = "subnet-id"
    values = [each.value]
  }
  filter {
    name   = "description"
    values = ["VPC Endpoint Interface ${aws_vpc_endpoint.apigw.id}"]
  }

  depends_on = [aws_vpc_endpoint.apigw]
}

# Registrar cada IP del VPC Endpoint como target (IP type target group)
resource "aws_lb_target_group_attachment" "vpce_apigw" {
  for_each = { for idx, s in aws_subnet.private : tostring(idx) => s.id }

  target_group_arn = aws_lb_target_group.vpce_apigw.arn
  target_id        = data.aws_network_interface.vpce_apigw[each.key].private_ip
  port             = 443
}

# -----------------------------------------------------------------------------
# Internal ALB — solo accesible desde dentro de la VPC
# -----------------------------------------------------------------------------
resource "aws_lb" "internal" {
  name               = "${var.project_name}-internal-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_internal.id]
  subnets            = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-internal-alb"
  }
}

# -----------------------------------------------------------------------------
# Listener HTTPS/443 con mTLS en modo "verify"
# - Termina TLS con el certificado del servidor (ACM imported)
# - Verifica el certificado del cliente contra el trust store
# - Solo reenvía al target group si el cert cliente es válido
# -----------------------------------------------------------------------------
resource "aws_lb_listener" "https_mtls" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.api_domain.arn

  mutual_authentication {
    mode            = "verify"
    trust_store_arn = aws_lb_trust_store.mtls.arn
  }

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vpce_apigw.arn
  }

  depends_on = [aws_lb_trust_store.mtls]
}
