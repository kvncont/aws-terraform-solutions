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
  sensitive   = true
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

output "efs_file_system_id" {
  description = "ID del EFS"
  value       = aws_efs_file_system.this.id
}

output "efs_security_group_id" {
  description = "ID del security group asociado a EFS"
  value       = aws_security_group.efs.id
}

output "efs_mount_target_ids" {
  description = "IDs de mount targets creados para EFS"
  value       = [for mt in aws_efs_mount_target.this : mt.id]
}

output "efs_access_point_id" {
  description = "ID del EFS Access Point"
  value       = aws_efs_access_point.this.id
}

output "eks_kubeconfig_command" {
  description = "Comando para configurar kubectl contra el cluster EKS"
  value       = "aws eks update-kubeconfig --region ${var.deploy_region} --name ${aws_eks_cluster.this.name}"
}

output "argocd_url" {
  description = "URL de acceso a ArgoCD"
  value       = aws_eks_capability.argocd[0].configuration[0].argo_cd[0].server_url
}

output "s3_bucket_name" {
  description = "Nombre del bucket S3 para archivos bootstrap"
  value       = aws_s3_bucket.this.bucket
}

output "s3_bucket_arn" {
  description = "ARN del bucket S3 para archivos bootstrap"
  value       = aws_s3_bucket.this.arn
}

output "s3_files_id" {
  description = "ID del S3 Files"
  value       = aws_s3files_file_system.this.id
}