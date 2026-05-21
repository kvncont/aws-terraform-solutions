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
  default     = "mtls-apigw"
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

variable "hosted_zone_id" {
  description = "ID del Hosted Zone de Route 53 para el dominio interno"
  type        = string
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
  default     = ""   # Si queda vacío se resuelve dinámicamente con un data source
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
