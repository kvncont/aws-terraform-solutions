locals {
  project_name               = lower(replace(var.project_name, "_", "-"))
  eks_cluster_name           = "eks-${local.project_name}"
  sg_controlplane_name       = "secgrp-${local.project_name}-controlplane"
  sg_shared_node_name        = "secgrp-${local.project_name}-shared-node"
  iam_role_eks_service_name  = "iam-rol-${local.project_name}-eks-svc"
  iam_policy_automode_name   = "iam-pol-${local.project_name}-eks-svc"
  iam_role_eks_node_name     = "iam-rol-${local.project_name}-eks-node-svc"
  oidc_provider_name         = "oidc-${local.project_name}"
  iam_role_eks_oidc_name     = "iam-rol-${local.project_name}-eks-oidc"
  iam_role_argocd_name       = "iam-rol-${local.project_name}-argocd"
  iam_role_cloudwatch_agent  = "iam-rol-${local.project_name}-cloudwatch-agent"
  iam_role_efs_csi_driver    = "iam-rol-${local.project_name}-efs-csi-driver"
  eks_capability_argocd_name = "eks-capability-${local.project_name}-argocd"
  eks_cluster_log_group_name = "/aws/eks/${local.eks_cluster_name}/cluster"
  eks_cluster_version        = var.cluster_version != null ? var.cluster_version : data.aws_eks_cluster_versions.this.cluster_versions[0].cluster_version

  create_vpc           = var.vpc_id == null || var.vpc_id == ""
  create_subnets       = var.subnet_ids == null || length(var.subnet_ids) == 0
  network_subnet_count = 2

  network_vpc_id = local.create_vpc ? aws_vpc.eks[0].id : var.vpc_id
  network_subnet_ids = local.create_subnets ? [
    for s in aws_subnet.eks : s.id
  ] : var.subnet_ids
}
