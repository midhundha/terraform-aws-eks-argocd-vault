####################################################################################
### Vault Namespace
####################################################################################
resource "kubernetes_namespace_v1" "vault" {
  metadata {
    name = var.vault_namespace
  }

  depends_on = [module.eks]
}

####################################################################################
### Vault Helm Release
####################################################################################
resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com/"
  chart      = "vault"
  version    = var.vault_chart_version
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name

  values = [
    yamlencode({
      server = {
        dev = {
          enabled      = true
          devRootToken = "devroot"
        }

        dataStorage = {
          enabled      = true
          storageClass = "gp2"
          size         = "1Gi"
          accessMode   = "ReadWriteOnce"
        }

        ingress = {
          enabled = true
          annotations = {
            "nginx.ingress.kubernetes.io/rewrite-target"     = "/"
            "nginx.ingress.kubernetes.io/ssl-redirect"       = "false"
            "nginx.ingress.kubernetes.io/force-ssl-redirect" = "false"
          }
          ingressClassName = "nginx"
          pathType         = "Prefix"
          hosts = [
            {
              host  = var.vault_hostname
              paths = ["/"]
            }
          ]
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace_v1.vault]
}