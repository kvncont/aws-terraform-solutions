# =============================================================================
# Outputs
# =============================================================================

output "vpc_id" {
  description = "ID de la VPC"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "IDs de las subnets privadas"
  value       = aws_subnet.private[*].id
}

output "vpc_endpoint_id" {
  description = "ID del VPC Endpoint para API Gateway"
  value       = aws_vpc_endpoint.apigw.id
}

output "vpc_endpoint_dns" {
  description = "DNS del VPC Endpoint (usar para requests internos)"
  value       = aws_vpc_endpoint.apigw.dns_entry[0].dns_name
}

output "api_gateway_id" {
  description = "ID del API Gateway (REST API v1)"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_gateway_invoke_url" {
  description = "URL de invocación del API Gateway (stage)"
  value       = "https://${aws_api_gateway_rest_api.main.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.default.stage_name}"
}

output "custom_domain_url" {
  description = "URL del dominio personalizado del API Gateway"
  value       = "https://${var.custom_domain}"
}

output "lambda_function_name" {
  description = "Nombre de la función Lambda"
  value       = aws_lambda_function.api_handler.function_name
}

output "lambda_function_arn" {
  description = "ARN de la función Lambda"
  value       = aws_lambda_function.api_handler.arn
}

output "s3_truststore_bucket" {
  description = "Nombre del bucket S3 que contiene el truststore"
  value       = aws_s3_bucket.truststore.bucket
}

output "ec2_instance_id" {
  description = "ID de la instancia EC2 para pruebas"
  value       = aws_instance.test_client.id
}

output "ec2_private_ip" {
  description = "IP privada de la EC2"
  value       = aws_instance.test_client.private_ip
}

output "acm_certificate_arn" {
  description = "ARN del certificado ACM para el custom domain"
  value       = aws_acm_certificate.api_domain.arn
}

output "curl_example" {
  description = "Ejemplo de curl fallido sin certificado cliente (debe ser rechazado por el ALB)"
  value       = "curl --cacert /etc/mtls/server-ca.crt https://${var.project_name}.${var.custom_domain}/hello"
}

output "curl_example_direct_vpce" {
  description = "Ejemplo de curl directo al VPC Endpoint"
  value       = "curl --cacert /etc/mtls/server-ca.crt https://${aws_vpc_endpoint.apigw.dns_entry[0].dns_name}/hello"
}

output "curl_example_direct_apigw" {
  description = "Ejemplo de curl directo al API Gateway"
  value       = "curl https://${aws_api_gateway_domain_name.main.regional_domain_name}/${aws_api_gateway_stage.default.stage_name}/hello"
}

output "nslookup_custom_domain" {
  description = "Comando para resolver el dominio personalizado desde la EC2"
  value       = "nslookup ${var.project_name}.${var.custom_domain} ${aws_instance.test_client.private_ip}"
}

output "ssm_download_certs_command" {
  description = "Comando SSM para descargar los certificados mTLS desde S3 a la EC2"
  value       = <<-EOT
    aws ssm send-command \
      --instance-ids "${aws_instance.test_client.id}" \
      --document-name "AWS-RunShellScript" \
      --parameters 'commands=[
        "aws s3 cp s3://${aws_s3_bucket.truststore.bucket}/mtls/server-ca.crt /etc/mtls/server-ca.crt",
        "chmod 644 /etc/mtls/server-ca.crt"
      ]'
  EOT
}
