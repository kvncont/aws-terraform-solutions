variable "deploy_region" {
  type        = string
  default     = "us-east-1"
  description = "Region de despliegue"
}

variable "project_name" {
  type        = string
  default     = "auto-mode"
  description = "Nombre corto del proyecto para prefijar recursos"
}

variable "cluster_version" {
  type        = string
  default     = "1.32"
  description = "Version de Kubernetes del cluster"
}

variable "admin_cidr" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "Lista de CIDRs de administración para acceso al API server"
}

variable "ingress_sg_to_port" {
  type        = number
  default     = 65535
  description = "Puerto máximo para reglas de ingress en security groups"
}

variable "vpc_id" {
  type        = string
  default     = null
  description = "ID de la VPC existente donde se desplegará el cluster. Si es null se crea una VPC"
}

variable "subnet_ids" {
  type        = list(string)
  default     = null
  description = "Lista de subnets existentes donde se desplegará el cluster. Si es null se crean 2 subnets"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.50.0.0/16"
  description = "CIDR para la VPC creada por el modulo"
}

variable "cluster_subnet_cidrs" {
  type        = list(string)
  default     = ["10.50.1.0/24", "10.50.2.0/24"]
  description = "CIDRs para subnets del cluster (minimo 2 en AZ distintas)"

  validation {
    condition     = length(var.cluster_subnet_cidrs) >= 2
    error_message = "Debes definir al menos 2 CIDRs en cluster_subnet_cidrs."
  }
}

variable "node_pools" {
  type        = list(string)
  default     = ["general-purpose", "system"]
  description = "Node pools para EKS Auto Mode"
}

variable "enable_argocd_bootstrap" {
  type        = bool
  default     = true
  description = "Habilita recursos Kubernetes/Helm de ArgoCD (segunda fase despues de crear el cluster)"
}

variable "argocd_private_repo_url" {
  type        = string
  default     = ""
  description = "URL HTTPS del repositorio privado de GitHub a registrar en ArgoCD"
}

variable "github_app_id" {
  type        = string
  default     = ""
  description = "GitHub App ID para autenticacion del repositorio privado"
}

variable "github_app_installation_id" {
  type        = string
  default     = ""
  description = "GitHub App Installation ID para autenticacion del repositorio privado"
}

variable "github_app_private_key" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Private key PEM de GitHub App"
}
