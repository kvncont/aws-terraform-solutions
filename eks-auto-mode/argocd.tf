###########################
##### ArgoCD Capability
###########################

resource "aws_eks_capability" "argocd" {
  depends_on = [
    aws_eks_cluster.this,
  ]

  count = var.enable_argocd_bootstrap ? 1 : 0

  cluster_name              = aws_eks_cluster.this.name
  capability_name           = "argocd"
  type                      = "ARGOCD"
  role_arn                  = aws_iam_role.argocd.arn
  delete_propagation_policy = "RETAIN"

  configuration {
    argo_cd {
      namespace = "argocd"

      aws_idc {
        idc_instance_arn = var.idc_instance_arn
      }

      rbac_role_mapping {
        identity {
          type = "SSO_GROUP"
          id   = var.argocd_admin_sso_group_id
        }
        role = "ADMIN"
      }
    }
  }



  tags = {
    Name = local.eks_capability_argocd_name
  }
}

resource "kubernetes_secret_v1" "argocd" {
  depends_on = [
    aws_eks_capability.argocd[0]
  ]

  count = var.enable_argocd_bootstrap ? 1 : 0

  metadata {
    name      = local.eks_cluster_name
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
    }
  }
  data = {
    name    = local.eks_cluster_name
    server  = aws_eks_cluster.this.arn
    project = "default"
  }

  type = "Opaque"
}

# Configura el acceso a un repo privado de GitHub usando una GitHub App
resource "kubernetes_secret_v1" "ms_control_plane_repo" {
  depends_on = [
    aws_eks_capability.argocd[0]
  ]

  count = var.enable_argocd_bootstrap ? 1 : 0

  metadata {
    name      = "ms-control-plane-repo"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    type                    = "git"
    url                     = "https://github.com/kvncont/ms-control-plane.git"
    githubAppID             = var.github_app_id
    githubAppInstallationID = var.github_app_installation_id
    githubAppPrivateKey     = var.github_app_private_key
  }

  type = "Opaque"
}

# Configura el acceso a un repo privado de GitHub usando una GitHub App
resource "kubernetes_secret_v1" "k8s_repo" {
  depends_on = [
    aws_eks_capability.argocd[0]
  ]

  count = var.enable_argocd_bootstrap ? 1 : 0

  metadata {
    name      = "k8s-repo"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    type                    = "git"
    url                     = "https://github.com/kvncont/k8s"
    githubAppID             = var.github_app_id
    githubAppInstallationID = var.github_app_installation_id
    githubAppPrivateKey     = var.github_app_private_key
  }

  type = "Opaque"
}

resource "helm_release" "projects" {
  depends_on = [
    aws_eks_capability.argocd[0],
    kubernetes_secret_v1.ms_control_plane_repo[0]
  ]

  count = var.enable_argocd_bootstrap ? 1 : 0

  name       = "projects"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  namespace  = "argocd"

  values = [
    templatefile("${path.module}/argocd-setup/projects/projects.yml", {
      cluster_server = aws_eks_cluster.this.arn
    })
  ]
}

resource "helm_release" "core" {
  depends_on = [
    helm_release.projects[0],
    kubernetes_secret_v1.ms_control_plane_repo[0]
  ]

  count = var.enable_argocd_bootstrap ? 1 : 0

  name       = "core"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  namespace  = "argocd"

  values = [
    templatefile("${path.module}/argocd-setup/application/core.yml", {
      cluster_server = aws_eks_cluster.this.arn
    })
  ]
}

resource "helm_release" "apps" {
  depends_on = [
    helm_release.projects[0],
    kubernetes_secret_v1.ms_control_plane_repo[0],
    helm_release.core[0]
  ]

  count = var.enable_argocd_bootstrap ? 1 : 0

  name       = "apps"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  namespace  = "argocd"

  values = [
    templatefile("${path.module}/argocd-setup/applicationset/apps.yml", {
      cluster_server = aws_eks_cluster.this.arn
    })
  ]
}