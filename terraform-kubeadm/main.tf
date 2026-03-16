resource "terraform_data" "hosts" {
  for_each = var.hosts

  triggers_replace = each.value.ip

  connection {
    host = each.value.ip
    port = each.value.port
    user = each.value.user
  }

  provisioner "remote-exec" {
    # script = each.value.type == "controlplane" ? "scripts/controlplane.sh" : "scripts/node.sh"
    script = each.value.type == "controlplane" ? "scripts/test.sh" : "scripts/test02.sh"
  }
}
