terraform {
  required_providers {
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.1.3"
    }
  }
}

resource "helm_release" "metallb" {
  name       = "metallb"
  namespace  = "metallb-system"
  repository = "https://metallb.github.io/metallb"
  chart      = "metallb"
  version    = "0.15.3"

  create_namespace = true
  atomic           = false
  timeout          = 900
  cleanup_on_fail  = false
  wait             = true
  wait_for_jobs    = true

  values = [
    file("${path.module}/values.yaml")
  ]
}

data "template_file" "ip_pool" {
  template = file("${path.module}/kube_objects/ip-pool.yaml")
  vars = {
    cluster_ip     = var.cluster_ip
  }
}

resource "kubectl_manifest" "ip_pool" {
  yaml_body = data.template_file.ip_pool.rendered

  depends_on = [
    helm_release.metallb
  ]
}