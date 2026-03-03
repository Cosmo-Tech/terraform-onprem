terraform {
  required_providers {
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.1.3"
    }
  }
}

locals {
  # Get the IP from the existing nodes
  cluster_ip = flatten([
    for node in data.kubernetes_nodes.all_nodes.nodes : [
      for addr in node.status[0].addresses : addr.address if addr.type == "InternalIP"
    ]
  ])[0]
}

data "kubernetes_nodes" "all_nodes" {}

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
  template = file("${path.module}/ip-pool.yaml")
  vars = {
    cluster_ip = local.cluster_ip
  }
}

resource "kubectl_manifest" "ip_pool" {
  yaml_body = data.template_file.ip_pool.rendered

  depends_on = [
    helm_release.metallb
  ]
}