###########################
##### EKS Service Role
###########################

resource "aws_iam_role" "eks_service_role" {
  name = local.iam_role_eks_service_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })
}

###########################
##### Auto Mode Policy
###########################

data "aws_iam_policy_document" "eks_automode_policy" {
  statement {
    sid    = "Compute"
    effect = "Allow"
    actions = [
      "ec2:CreateFleet",
      "ec2:RunInstances",
      "ec2:CreateLaunchTemplate",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks:eks-cluster-name"
      values   = ["$${aws:PrincipalTag/eks:eks-cluster-name}"]
    }
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/eks:kubernetes-node-class-name"
      values   = ["*"]
    }
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/eks:kubernetes-node-pool-name"
      values   = ["*"]
    }
  }

  statement {
    sid    = "Storage"
    effect = "Allow"
    actions = [
      "ec2:CreateVolume",
      "ec2:CreateSnapshot",
    ]
    resources = [
      "arn:aws:ec2:*:*:volume/*",
      "arn:aws:ec2:*:*:snapshot/*",
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks:eks-cluster-name"
      values   = ["$${aws:PrincipalTag/eks:eks-cluster-name}"]
    }
  }

  statement {
    sid    = "Networking"
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks:eks-cluster-name"
      values   = ["$${aws:PrincipalTag/eks:eks-cluster-name}"]
    }
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/eks:kubernetes-cni-node-name"
      values   = ["*"]
    }
  }

  statement {
    sid    = "LoadBalancer"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:CreateRule",
      "ec2:CreateSecurityGroup",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks:eks-cluster-name"
      values   = ["$${aws:PrincipalTag/eks:eks-cluster-name}"]
    }
  }

  statement {
    sid    = "ShieldProtection"
    effect = "Allow"
    actions = [
      "shield:CreateProtection",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks:eks-cluster-name"
      values   = ["$${aws:PrincipalTag/eks:eks-cluster-name}"]
    }
  }

  statement {
    sid    = "ShieldTagResource"
    effect = "Allow"
    actions = [
      "shield:TagResource",
    ]
    resources = ["arn:aws:shield::*:protection/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks:eks-cluster-name"
      values   = ["$${aws:PrincipalTag/eks:eks-cluster-name}"]
    }
  }
}

resource "aws_iam_role_policy" "automode_policy" {
  name   = local.iam_policy_automode_name
  role   = aws_iam_role.eks_service_role.id
  policy = data.aws_iam_policy_document.eks_automode_policy.json
}

resource "aws_iam_role_policy_attachments_exclusive" "eks_service_attach" {
  role_name = aws_iam_role.eks_service_role.name
  policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController",
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSComputePolicy",
    "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy",
    "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy",
  ]
}

###########################
##### Node Role (Auto Mode)
###########################

resource "aws_iam_role" "eks_node" {
  name = local.iam_role_eks_node_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_worker_minimal" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy"
  role       = aws_iam_role.eks_node.name
}

resource "aws_iam_role_policy_attachment" "eks_node_ecr_pull" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
  role       = aws_iam_role.eks_node.name
}

###########################
##### OIDC Provider
###########################

data "tls_certificate" "eks_cluster" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_cluster.certificates[0].sha1_fingerprint]
  url             = data.tls_certificate.eks_cluster.url
  tags = {
    Name = local.oidc_provider_name
  }
}

resource "aws_iam_role" "eks_cluster_oidc" {
  name = local.iam_role_eks_oidc_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks_cluster.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks_cluster.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-node"
          }
        }
      }
    ]
  })
}

###########################
##### ArgoCD Pod Identity
###########################

resource "aws_iam_role" "argocd" {
  name = local.iam_role_argocd_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "capabilities.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })
}

# EKS crea automaticamente un Access Entry para el Capability Role cuando se
# aprovisiona la capacidad de ArgoCD, pero no otorga permisos RBAC de Kubernetes.
# Esta asociacion asigna explicitamente AmazonEKSClusterAdminPolicy a nivel de
# cluster para que ArgoCD pueda listar y sincronizar todos los recursos (p. ej., CSINode).
resource "aws_eks_access_policy_association" "argocd_cluster_admin" {
  depends_on = [
    aws_eks_capability.argocd[0],
  ]

  count = var.enable_argocd_bootstrap ? 1 : 0

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_iam_role.argocd.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

###########################
##### Policy for pod identities (CloudWatch Agent, EFS CSI Driver)
###########################

data "aws_iam_policy_document" "pod_identity_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

###########################
##### CloudWatch Agent Pod Identity
###########################

resource "aws_iam_role" "cloudwatch_agent" {
  name               = local.iam_role_cloudwatch_agent
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.cloudwatch_agent.name
}

resource "aws_eks_pod_identity_association" "cloudwatch_agent" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "amazon-cloudwatch"
  service_account = "cloudwatch-agent"
  role_arn        = aws_iam_role.cloudwatch_agent.arn
}

###########################
##### EFS CSI Driver Controller Pod Identity
###########################

resource "aws_iam_role" "efs_csi_driver" {
  name               = local.iam_role_efs_csi_driver
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
}

resource "aws_iam_role_policy_attachment" "efs_csi_driver" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
  role       = aws_iam_role.efs_csi_driver.name
}

resource "aws_iam_role_policy_attachment" "efs_csi_driver_s3files" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonS3FilesCSIDriverPolicy"
  role       = aws_iam_role.efs_csi_driver.name
}

resource "aws_iam_role_policy_attachment" "efs_csi_driver_s3files_custom" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FilesClientFullAccess"
  role       = aws_iam_role.efs_csi_driver.name
}

resource "aws_eks_pod_identity_association" "efs_csi_driver" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "efs-csi-controller-sa"
  role_arn        = aws_iam_role.efs_csi_driver.arn
}

###########################
##### EFS CSI Driver Node Pod Identity
###########################

resource "aws_iam_role" "efs_csi_driver_node" {
  name               = "iam-role-${local.project_name}-efs-csi-driver-node"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
}

resource "aws_iam_role_policy_attachment" "efs_csi_driver_node_s3files_custom" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FilesClientFullAccess"
  role       = aws_iam_role.efs_csi_driver_node.name
}

resource "aws_iam_role_policy_attachment" "efs_csi_driver_node_s3_readonly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  role       = aws_iam_role.efs_csi_driver_node.name
}

resource "aws_iam_role_policy_attachment" "efs_csi_driver_node_efs_utils" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticFileSystemsUtils"
  role       = aws_iam_role.efs_csi_driver_node.name
}

resource "aws_eks_pod_identity_association" "efs_csi_driver_node" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "efs-csi-node-sa"
  role_arn        = aws_iam_role.efs_csi_driver_node.arn
}

###########################
##### S3Files Role
###########################

resource "aws_iam_role" "s3files" {
  name = "iam-role-${local.project_name}-s3files"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "elasticfilesystem.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3files:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:file-system/*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "s3files_permissions" {
  name = "iam-policy-${local.project_name}-s3files"
  role = aws_iam_role.s3files.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3BucketPermissions"
        Effect = "Allow"
        Action = [
          "s3:ListBucket*"
        ]
        Resource = aws_s3_bucket.this.arn
        Condition = {
          StringEquals = {
            "aws:ResourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "S3ObjectPermissions"
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:DeleteObject*",
          "s3:GetObject*",
          "s3:List*",
          "s3:PutObject*"
        ]
        Resource = "${aws_s3_bucket.this.arn}/*"
      },
      {
        Sid    = "UseKmsKeyWithS3Files"
        Effect = "Allow"
        Action = [
          "kms:GenerateDataKey",
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncryptFrom",
          "kms:ReEncryptTo"
        ]
        Resource = "arn:aws:kms:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Sid    = "EventBridgeManage"
        Effect = "Allow"
        Action = [
          "events:DeleteRule",
          "events:DisableRule",
          "events:EnableRule",
          "events:PutRule",
          "events:PutTargets",
          "events:RemoveTargets"
        ]
        Condition = {
          StringEquals = {
            "events:ManagedBy" = "elasticfilesystem.amazonaws.com"
          }
        }
        Resource = [
          "arn:aws:events:*:*:rule/DO-NOT-DELETE-S3-Files*"
        ]
      },
      {
        Sid    = "EventBridgeRead"
        Effect = "Allow"
        Action = [
          "events:DescribeRule",
          "events:ListRuleNamesByTarget",
          "events:ListRules",
          "events:ListTargetsByRule"
        ]
        Resource = [
          "arn:aws:events:*:*:rule/*"
        ]
      }
    ]
  })
}