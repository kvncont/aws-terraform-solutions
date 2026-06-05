###########################
##### EKS Cluster (Auto Mode)
###########################

resource "aws_eks_cluster" "this" {
  depends_on = [aws_cloudwatch_log_group.eks_cluster]

  name    = local.cluster_name
  version = var.cluster_version

  role_arn = aws_iam_role.eks_service_role.arn

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = false
    security_group_ids = [
      aws_security_group.eks_cluster_sg.id
    ]
    subnet_ids = local.network_subnet_ids
  }

  bootstrap_self_managed_addons = false

  # Auto Mode: compute
  compute_config {
    enabled       = true
    node_pools    = var.node_pools
    node_role_arn = aws_iam_role.eks_node.arn
  }

  # Auto Mode: networking (ELB)
  kubernetes_network_config {
    elastic_load_balancing {
      enabled = true
    }
  }

  # Auto Mode: storage (EBS)
  storage_config {
    block_storage {
      enabled = true
    }
  }

  enabled_cluster_log_types = [
    "api",
    "authenticator",
    "audit",
    "scheduler",
    "controllerManager"
  ]

  tags = {
    Name = local.cluster_name
  }
}

###########################
##### CloudWatch Log Group
###########################

resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = local.eks_cluster_log_group_name
  retention_in_days = 30
}
