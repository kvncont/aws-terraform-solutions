# =============================================================================
# VPC Endpoint para API Gateway (execute-api)
# Permite consumir el API desde dentro de la VPC sin salir a Internet.
# El API Gateway se configura como PRIVATE, por lo que SOLO puede ser
# invocado a través de este endpoint.
# =============================================================================

resource "aws_vpc_endpoint" "apigw" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.execute-api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpce_apigw.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-vpce-execute-api"
  }
}

# =============================================================================
# Resource Policy del API Gateway
# Restringe el acceso EXCLUSIVAMENTE al VPC Endpoint creado arriba.
# Cualquier llamada que no pase por el VPC Endpoint será denegada (403).
# =============================================================================

data "aws_iam_policy_document" "apigw_resource_policy" {
  statement {
    sid    = "AllowVPCEndpointOnly"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["execute-api:Invoke"]
    resources = ["${aws_api_gateway_rest_api.main.execution_arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceVpce"
      values   = [aws_vpc_endpoint.apigw.id]
    }
  }

  statement {
    sid    = "DenyPublicAccess"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["execute-api:Invoke"]
    resources = ["${aws_api_gateway_rest_api.main.execution_arn}/*"]

    condition {
      test     = "StringNotEquals"
      variable = "aws:SourceVpce"
      values   = [aws_vpc_endpoint.apigw.id]
    }
  }
}
