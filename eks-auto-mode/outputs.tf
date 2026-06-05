output "cluster_name" {
  description = "Nombre del cluster EKS"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Endpoint del API server del cluster EKS"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority" {
  description = "Certificado CA del cluster EKS"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_version" {
  description = "Version de Kubernetes del cluster"
  value       = aws_eks_cluster.this.version
}

output "cluster_security_group_id" {
  description = "Security group ID del cluster EKS"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "oidc_provider_url" {
  description = "URL del OIDC provider"
  value       = replace(aws_iam_openid_connect_provider.eks_cluster.url, "https://", "")
}

output "oidc_provider_arn" {
  description = "ARN del OIDC provider"
  value       = aws_iam_openid_connect_provider.eks_cluster.arn
}

output "node_role_arn" {
  description = "ARN del IAM role de los nodos"
  value       = aws_iam_role.eks_node.arn
}

output "argocd_role_arn" {
  description = "ARN del IAM role para ArgoCD"
  value       = aws_iam_role.argocd.arn
}

output "vpc_id" {
  description = "VPC ID efectiva usada por el cluster"
  value       = local.network_vpc_id
}

output "subnet_ids" {
  description = "Subnets efectivas usadas por el cluster"
  value       = local.network_subnet_ids
}
