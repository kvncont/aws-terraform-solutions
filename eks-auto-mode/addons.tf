###########################
##### Metrics Server
###########################

data "aws_eks_addon_version" "metrics_server" {
  addon_name         = "metrics-server"
  kubernetes_version = aws_eks_cluster.this.version
  most_recent        = true
}

resource "aws_eks_addon" "metrics_server" {
  depends_on = [
    aws_eks_cluster.this
  ]

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "metrics-server"
  addon_version               = data.aws_eks_addon_version.metrics_server.version
  resolve_conflicts_on_update = "OVERWRITE"
  resolve_conflicts_on_create = "OVERWRITE"

  configuration_values = jsonencode({
    replicas = 2
    nodeSelector = {
      "karpenter.sh/nodepool" = "system"
    }
    tolerations = [
      {
        key      = "CriticalAddonsOnly"
        operator = "Exists"
      }
    ]
    topologySpreadConstraints = [
      {
        maxSkew           = 1
        minDomains        = 2
        topologyKey       = "topology.kubernetes.io/zone"
        whenUnsatisfiable = "DoNotSchedule"
        labelSelector = {
          matchLabels = {
            "app.kubernetes.io/name" = "metrics-server"
          }
        }
      }
    ]
  })
}

###########################
##### CloudWatch Observability
###########################

data "aws_eks_addon_version" "cloudwatch" {
  addon_name         = "amazon-cloudwatch-observability"
  kubernetes_version = aws_eks_cluster.this.version
  most_recent        = true
}

resource "aws_eks_addon" "cloudwatch" {
  depends_on = [
    aws_eks_cluster.this
  ]

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "amazon-cloudwatch-observability"
  addon_version               = data.aws_eks_addon_version.cloudwatch.version
  resolve_conflicts_on_update = "OVERWRITE"
  resolve_conflicts_on_create = "OVERWRITE"

  configuration_values = jsonencode({
    otelContainerInsights = {
      enabled = false
    }
    applicationSignals = {
      enabled = false
    }
  })
}

###########################
##### AWS Secrets Store CSI Driver Provider
###########################

data "aws_eks_addon_version" "secrets_store_csi_provider_aws" {
  addon_name         = "aws-secrets-store-csi-driver-provider"
  kubernetes_version = aws_eks_cluster.this.version
  most_recent        = true
}

resource "aws_eks_addon" "secrets_store_csi_provider_aws" {
  depends_on = [
    aws_eks_cluster.this
  ]

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "aws-secrets-store-csi-driver-provider"
  addon_version               = data.aws_eks_addon_version.secrets_store_csi_provider_aws.version
  resolve_conflicts_on_update = "OVERWRITE"
  resolve_conflicts_on_create = "OVERWRITE"
}

###########################
##### EFS CSI Driver
###########################

data "aws_eks_addon_version" "efs_csi_driver" {
  addon_name         = "aws-efs-csi-driver"
  kubernetes_version = aws_eks_cluster.this.version
  most_recent        = true
}

resource "aws_eks_addon" "efs_csi_driver" {
  depends_on = [
    aws_eks_pod_identity_association.efs_csi_driver
  ]

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "aws-efs-csi-driver"
  addon_version               = data.aws_eks_addon_version.efs_csi_driver.version
  resolve_conflicts_on_update = "OVERWRITE"
  resolve_conflicts_on_create = "OVERWRITE"
}
