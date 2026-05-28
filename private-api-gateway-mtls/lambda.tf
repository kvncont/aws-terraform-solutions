# =============================================================================
# Lambda Function
# =============================================================================

# Empaquetar el código Python en un ZIP
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/.terraform/lambda_package.zip"
}

resource "aws_lambda_function" "api_handler" {
  function_name    = "${var.project_name}-api-handler"
  description      = "Handler del API Gateway con mTLS - retorna info de la request y del certificado cliente"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.handler"
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  # Despliegue dentro de la VPC para que no necesite salir a Internet
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      ENVIRONMENT  = var.environment
      PROJECT_NAME = var.project_name
    }
  }

  # Trazabilidad con X-Ray
  tracing_config {
    mode = "Active"
  }

  tags = {
    Name = "${var.project_name}-api-handler"
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_vpc_access,
    aws_cloudwatch_log_group.lambda,
  ]
}

# =============================================================================
# CloudWatch Log Group para la Lambda
# =============================================================================

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-api-handler"
  retention_in_days = 14

  tags = {
    Name = "${var.project_name}-lambda-logs"
  }
}

# =============================================================================
# Permiso: API Gateway puede invocar la Lambda
# =============================================================================

resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*/*"
}
