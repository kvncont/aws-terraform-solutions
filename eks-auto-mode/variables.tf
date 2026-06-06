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

variable "idc_instance_arn" {
  type        = string
  default     = null
  description = "ARN del IAM Identity Center (SSO) instance para autenticacion de ArgoCD. Requerido cuando enable_argocd_bootstrap = true"

  validation {
    condition     = !var.enable_argocd_bootstrap || var.idc_instance_arn == "" || can(regex("^arn:aws:sso:::instance/ssoins-[a-z0-9]+$", var.idc_instance_arn))
    error_message = "Cuando enable_argocd_bootstrap = true, idc_instance_arn debe tener el formato arn:aws:sso:::instance/ssoins-<id> o estar vacio."
  }
}

variable "argocd_admin_sso_group_id" {
  type        = string
  default     = null
  description = "ID del grupo SSO de administrador de ArgoCD. Requerido cuando enable_argocd_bootstrap = true"

  validation {
    condition     = !var.enable_argocd_bootstrap || var.argocd_admin_sso_group_id == null || var.argocd_admin_sso_group_id == "" || can(regex("^[a-z0-9-]+$", var.argocd_admin_sso_group_id))
    error_message = "Cuando enable_argocd_bootstrap = true, argocd_admin_sso_group_id debe estar vacio o tener un formato valido de identificador SSO."
  }
}

variable "enable_argocd_bootstrap" {
  type        = bool
  default     = true
  description = "Habilita recursos Kubernetes/Helm de ArgoCD (segunda fase despues de crear el cluster)"
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
