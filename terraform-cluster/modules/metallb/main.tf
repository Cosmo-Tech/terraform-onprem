terraform {
  required_providers {
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.1.3"
    }
  }
}


# IPAddressPool object required for Metallb
data "template_file" "ipaddresspool" {
  template = file("${path.module}/kube_objects/ipaddresspool.yaml")
  vars = {
    ip_address_for_web_services = var.ip_address_for_web_services
  }
}

resource "kubectl_manifest" "ipaddresspool" {
  yaml_body = data.template_file.ipaddresspool.rendered

  depends_on = [
    data.template_file.ipaddresspool
  ]
}


# L2Advertisement object required for Metallb
data "template_file" "l2advertisement" {
  template = file("${path.module}/kube_objects/l2advertisement.yaml")
}

resource "kubectl_manifest" "l2advertisement" {
  yaml_body = data.template_file.l2advertisement.rendered

  depends_on = [
    data.template_file.l2advertisement
  ]
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

  depends_on = [
    kubectl_manifest.ipaddresspool,
    kubectl_manifest.l2advertisement
  ]
}
