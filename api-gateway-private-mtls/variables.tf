# =============================================================================
# Variables globales
# =============================================================================

variable "aws_region" {
  description = "Región de AWS donde se desplegará la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre del proyecto (usado en tags y nombres de recursos)"
  type        = string
  default     = "apigw-private-mtls"
}

variable "environment" {
  description = "Ambiente de despliegue"
  type        = string
  default     = "dev"
}

# =============================================================================
# VPC
# =============================================================================

variable "vpc_cidr" {
  description = "CIDR block de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "CIDRs de subnets privadas"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "availability_zones" {
  description = "Zonas de disponibilidad"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# =============================================================================
# Dominio y certificados
# =============================================================================

variable "custom_domain" {
  description = "Dominio personalizado para el API Gateway (debe existir en Route 53)"
  type        = string
  default     = "api.internal.example.com"
}

variable "ownership_verification_certificate_arn" {
  description = <<-EOT
    ARN de un certificado ACM público (NO importado, NO Private CA) que cubra el mismo
    dominio o un dominio padre de custom_domain. Requerido por API Gateway cuando el
    certificado regional proviene de una ACM Private CA.
    Ejemplo: si custom_domain = "api.internal.example.com", este cert debe cubrir
    "api.internal.example.com", "*.internal.example.com" o "*.example.com".
    Dejar vacío omite el argumento (el apply fallará en aws_api_gateway_domain_name).
  EOT
  type        = string
  default     = ""
}

variable "truststore_s3_key" {
  description = "Clave S3 del archivo truststore.pem (Client CA)"
  type        = string
  default     = "mtls/truststore.pem"
}

# =============================================================================
# EC2
# =============================================================================

variable "ec2_instance_type" {
  description = "Tipo de instancia EC2 para pruebas"
  type        = string
  default     = "t3.micro"
}

variable "ec2_ami_id" {
  description = "AMI ID para la instancia EC2 (Amazon Linux 2023)"
  type        = string
  default     = "" # Si queda vacío se resuelve dinámicamente con un data source
}

variable "ec2_key_pair_name" {
  description = "Nombre del Key Pair para acceso SSH a la EC2"
  type        = string
  default     = ""
}

# =============================================================================
# Lambda
# =============================================================================

variable "lambda_runtime" {
  description = "Runtime de Lambda"
  type        = string
  default     = "python3.12"
}

variable "lambda_timeout" {
  description = "Timeout de Lambda en segundos"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Memoria de Lambda en MB"
  type        = number
  default     = 256
}
