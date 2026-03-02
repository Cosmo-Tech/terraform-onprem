terraform {
  required_providers {
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.1.3"
    }
  }
}

resource "helm_release" "longhorn" {
  name       = "longhorn"
  namespace  = "longhorn-system"
  repository = "https://charts.longhorn.io"
  chart      = "longhorn"
  version    = "1.11.0"

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

data "template_file" "backup" {
  template = file("${path.module}/backup.yaml")
}

resource "kubectl_manifest" "backup" {
  yaml_body = data.template_file.backup.rendered

  depends_on = [
    helm_release.longhorn
  ]
}
