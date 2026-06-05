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

resource "aws_iam_policy" "automode_policy" {
  name   = local.iam_policy_automode_name
  policy = data.aws_iam_policy_document.eks_automode_policy.json
  tags = {
    Name = local.iam_policy_automode_name
  }
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
    aws_iam_policy.automode_policy.arn
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

data "aws_iam_policy_document" "eks_cluster_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks_cluster.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks_cluster.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "eks_cluster_oidc" {
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role_policy.json
  name               = local.iam_role_eks_oidc_name
}

###########################
##### ArgoCD Pod Identity
###########################

data "aws_iam_policy_document" "argocd_assume" {
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

resource "aws_iam_role" "argocd" {
  name               = local.iam_role_argocd_name
  assume_role_policy = data.aws_iam_policy_document.argocd_assume.json
  tags = {
    Name = local.iam_role_argocd_name
  }
}

resource "aws_eks_pod_identity_association" "argocd" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "argocd"
  service_account = "argocd-server"
  role_arn        = aws_iam_role.argocd.arn
}

###########################
##### CloudWatch Agent Pod Identity
###########################

data "aws_iam_policy_document" "cloudwatch_agent_assume" {
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

resource "aws_iam_role" "cloudwatch_agent" {
  name               = local.iam_role_cloudwatch_agent
  assume_role_policy = data.aws_iam_policy_document.cloudwatch_agent_assume.json
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
