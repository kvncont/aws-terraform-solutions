# =============================================================================
# API Gateway v1 (REST API) — PRIVADO con mTLS
# =============================================================================

resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project_name}-api"
  description = "API privado con mTLS - solo accesible desde la VPC"

  # PRIVATE: solo accesible a través del VPC Endpoint
  endpoint_configuration {
    types            = ["PRIVATE"]
    vpc_endpoint_ids = [aws_vpc_endpoint.apigw.id]
  }

  tags = {
    Name = "${var.project_name}-api"
  }
}

# =============================================================================
# Resource Policy — restringe acceso exclusivamente al VPC Endpoint
# =============================================================================

resource "aws_api_gateway_rest_api_policy" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  policy      = data.aws_iam_policy_document.apigw_resource_policy.json
}

# =============================================================================
# Resources (paths)
# =============================================================================

resource "aws_api_gateway_resource" "hello" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "hello"
}

# =============================================================================
# Method (mTLS gestiona la autenticación — authorization = NONE en API GW)
# =============================================================================

resource "aws_api_gateway_method" "hello_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.hello.id
  http_method   = "GET"
  authorization = "NONE"
}

# =============================================================================
# Integration Lambda Proxy (AWS_PROXY)
# integration_http_method siempre es POST para Lambda
# =============================================================================

resource "aws_api_gateway_integration" "hello" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.hello.id
  http_method             = aws_api_gateway_method.hello_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_handler.invoke_arn
}

# =============================================================================
# Deployment
# El trigger sha1 fuerza un redeploy cuando cambia cualquier recurso/método/integración
# =============================================================================

resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.hello.id,
      aws_api_gateway_method.hello_get.id,
      aws_api_gateway_integration.hello,
      aws_api_gateway_rest_api_policy.main.policy,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.hello,
    aws_api_gateway_rest_api_policy.main,
  ]
}

# =============================================================================
# Stage
# =============================================================================

resource "aws_api_gateway_stage" "default" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  deployment_id = aws_api_gateway_deployment.main.id
  stage_name    = var.environment

  xray_tracing_enabled = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigw.arn

    format = jsonencode({
      requestId              = "$context.requestId"
      sourceIp               = "$context.identity.sourceIp"
      requestTime            = "$context.requestTime"
      protocol               = "$context.protocol"
      httpMethod             = "$context.httpMethod"
      resourcePath           = "$context.resourcePath"
      status                 = "$context.status"
      responseLength         = "$context.responseLength"
      integrationErrorMsg    = "$context.integrationErrorMessage"
      # mTLS — en REST API v1 el contexto del cert cliente está en identity
      clientCertSubject      = "$context.identity.clientCert.subjectDN"
      clientCertIssuer       = "$context.identity.clientCert.issuerDN"
      clientCertSerialNumber = "$context.identity.clientCert.serialNumber"
    })
  }

  tags = {
    Name = "${var.project_name}-stage-${var.environment}"
  }

  depends_on = [
    aws_cloudwatch_log_group.apigw,
    aws_api_gateway_account.main,
  ]
}

# Throttling y métricas por método
resource "aws_api_gateway_method_settings" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.default.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled        = true
    logging_level          = "INFO"
    data_trace_enabled     = false
    throttling_burst_limit = 100
    throttling_rate_limit  = 50
  }

  depends_on = [aws_api_gateway_account.main]
}

# =============================================================================
# CloudWatch Log Group para API Gateway
# =============================================================================

resource "aws_cloudwatch_log_group" "apigw" {
  name              = "/aws/apigateway/${var.project_name}"
  retention_in_days = 14

  tags = {
    Name = "${var.project_name}-apigw-logs"
  }
}

# =============================================================================
# Custom Domain Name
# En REST API v1 el mTLS se configura aquí, no en el REST API directamente
# =============================================================================

resource "aws_api_gateway_domain_name" "main" {
  domain_name              = var.custom_domain
  regional_certificate_arn = aws_acm_certificate_validation.api_domain.certificate_arn
  security_policy          = "TLS_1_2"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  mutual_tls_authentication {
    truststore_uri     = "s3://${aws_s3_bucket.truststore.bucket}/${aws_s3_object.truststore_pem.key}"
    truststore_version = aws_s3_object.truststore_pem.version_id
  }

  tags = {
    Name = "${var.project_name}-custom-domain"
  }

  depends_on = [aws_acm_certificate_validation.api_domain]
}

# Mapeo del custom domain al stage
resource "aws_api_gateway_base_path_mapping" "main" {
  api_id      = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.default.stage_name
  domain_name = aws_api_gateway_domain_name.main.domain_name
}
