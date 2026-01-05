####################################################################################
### Route53 DNS Record for ArgoCD (pointing to NGINX Ingress NLB)
####################################################################################
resource "aws_route53_record" "argocd" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.argocd_subdomain
  type    = "A"

  alias {
    name                   = data.kubernetes_service_v1.nginx_ingress_controller.status.0.load_balancer.0.ingress.0.hostname
    zone_id                = data.aws_lb_hosted_zone_id.nlb.id # "Z26RNL4JYFTOTI" => NLB zone ID for us-east-1
    evaluate_target_health = true
  }

  depends_on = [helm_release.argocd, data.kubernetes_service_v1.nginx_ingress_controller]
}

####################################################################################
### Route53 DNS Record for Node.js App (pointing to NGINX Ingress NLB)
####################################################################################

resource "aws_route53_record" "nodejs_app" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.app_subdomain
  type    = "A"

  alias {
    name                   = data.kubernetes_service_v1.nginx_ingress_controller.status.0.load_balancer.0.ingress.0.hostname
    zone_id                = data.aws_lb_hosted_zone_id.nlb.id # "Z26RNL4JYFTOTI" => NLB zone ID for us-east-1
    evaluate_target_health = true
  }

  depends_on = [helm_release.nginx_ingress]
}

####################################################################################
### Route53 DNS Record for Hashicorp Vault App (pointing to NGINX Ingress NLB)
####################################################################################
resource "aws_route53_record" "vault_app" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.vault_subdomain
  type    = "A"

  alias {
    name                   = data.kubernetes_service_v1.nginx_ingress_controller.status.0.load_balancer.0.ingress.0.hostname
    zone_id                = data.aws_lb_hosted_zone_id.nlb.id # "Z26RNL4JYFTOTI" => NLB zone ID for us-east-1
    evaluate_target_health = true
  }

  depends_on = [helm_release.nginx_ingress]
}