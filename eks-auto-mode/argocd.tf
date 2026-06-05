###########################
##### ArgoCD Capability
###########################

resource "aws_eks_capability" "argocd" {
  depends_on = [
    aws_eks_cluster.this
  ]

  count                     = var.enable_argocd_bootstrap ? 1 : 0

  cluster_name              = aws_eks_cluster.this.name
  capability_name           = "argocd"
  type                      = "ARGOCD"
  role_arn                  = aws_iam_role.argocd.arn
  delete_propagation_policy = "RETAIN"

  tags = {
    Name = local.eks_capability_argocd_name
  }
}

resource "kubernetes_secret_v1" "argocd" {
  depends_on = [
    aws_eks_capability.argocd
  ]

  count = var.enable_argocd_bootstrap ? 1 : 0

  metadata {
    name      = local.cluster_name
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
    }
  }
  data = {
    name    = local.cluster_name
    server  = aws_eks_cluster.this.endpoint
    project = "default"
  }

  type = "Opaque"
}

resource "kubernetes_secret_v1" "argocd_github_app_repo" {
  depends_on = [
    aws_eks_capability.argocd
  ]

  count = var.enable_argocd_bootstrap ? 1 : 0

  metadata {
    name      = "repo-github-app"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    github-privateKey = var.github_app_private_key
  }

  type = "Opaque"
}

resource "kubernetes_config_map_v1" "argocd_github_repo_config" {
  depends_on = [
    aws_eks_capability.argocd,
    kubernetes_secret_v1.argocd_github_app_repo
  ]

  count = var.enable_argocd_bootstrap ? 1 : 0

  metadata {
    name      = "argocd-github-repo-config"
    namespace = "argocd"
  }

  data = {
    appID          = var.github_app_id
    installationID = var.github_app_installation_id
    privateKey     = "$github-privateKey"
  }
}

resource "helm_release" "argocd_apps" {
  depends_on = [
    aws_eks_capability.argocd,
    kubernetes_secret_v1.argocd_github_app_repo
  ]

  count = var.enable_argocd_bootstrap ? 1 : 0

  name       = "argocd-apps"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  namespace  = "argocd"

  values = [
    yamlencode({
      applicationsets = {
        test-appset = {
          generators = [
            {
              list = {
                elements = [
                  {
                    name = "guestbook"
                    path = "guestbook"
                  },
                  {
                    name = "helm-guestbook"
                    path = "helm-guestbook"
                  }
                ]
              }
            }
          ]
          template = {
            metadata = {
              name = "{{name}}"
            }
            spec = {
              project = "default"
              source = {
                repoURL        = var.argocd_private_repo_url
                targetRevision = "HEAD"
                path           = "{{path}}"
              }
              destination = {
                server    = aws_eks_cluster.this.arn
                namespace = "default"
              }
              syncPolicy = {
                automated = {
                  prune    = false
                  selfHeal = false
                }
                syncOptions = ["CreateNamespace=true"]
              }
            }
          }
        }
      }
    })
  ]
}
