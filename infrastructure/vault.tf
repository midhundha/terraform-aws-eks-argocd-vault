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
  namespace  = kubernetes_namespace_v1.vault.metadata[0].name

  values = [
    yamlencode({
      server = {
        dev = {
          enabled      = true
          devRootToken = var.vault_token
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

####################################################################################
### Vault Configuration
####################################################################################
data "kubernetes_service_account_v1" "vault_sa" {
  metadata {
    name      = "vault"
    namespace = kubernetes_namespace_v1.vault.metadata[0].name
  }

  depends_on = [helm_release.vault]
}

data "kubernetes_secret_v1" "vault_sa_token" {
  metadata {
    name      = data.kubernetes_service_account_v1.vault_sa.secret[0].name
    namespace = kubernetes_namespace_v1.vault.metadata[0].name
  }

  depends_on = [data.kubernetes_service_account_v1.vault_sa]
}

locals {
  vault_token_reviewer_jwt = base64decode(data.kubernetes_secret_v1.vault_sa_token.data["token"])
  vault_ca_cert            = base64decode(data.kubernetes_secret_v1.vault_sa_token.data["ca.crt"])
}

resource "vault_auth_backend" "kubernetes" {
  type        = "kubernetes"
  description = "Kubernetes auth backend for Vault"
  path        = "kubernetes"

  depends_on = [helm_release.vault]
}

resource "vault_kubernetes_auth_backend_config" "k8s_config" {
  backend            = vault_auth_backend.kubernetes.path
  kubernetes_host    = "https://kubernetes.default.svc" # cluster API
  kubernetes_ca_cert = local.vault_ca_cert
  token_reviewer_jwt = local.vault_token_reviewer_jwt
  issuer             = "https://kubernetes.default.svc" # optional
}

resource "vault_policy" "webapp_policy" {
  name   = "webapp-policy"
  policy = <<EOT
path "secret/data/webapp" {
  capabilities = ["read", "list"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "app_role" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "webapp-role"
  bound_service_account_names      = ["app-sa"]
  bound_service_account_namespaces = ["secret-app"]
  token_policies                   = [vault_policy.webapp_policy.name]
  token_ttl                        = 300
}

resource "vault_mount" "secret" {
  path = "secret"
  type = "kv"
  options = {
    version = "2"
  }
  description = "KV_V2 mount for webapp secrets"
}

resource "vault_kv_secret_v2" "webapp_secret" {
  mount = vault_mount.secret.path
  name  = "webapp"
  data_json = jsonencode({
    my_secret = "super-secret-value"
  })
}