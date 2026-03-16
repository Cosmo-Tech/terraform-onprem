# locals {
#   script = "install_kubeadm.sh"
# }


# resource "terraform_data" "hosts" {
#   for_each = var.hosts

#   connection {
#     host = each.value.ip
#     port = each.value.port
#     user = each.value.user
#   }

#   #   provisioner "remote-exec" {
#   #     script = each.value.type == "controlplane" ? "scripts/controlplane.sh" : "scripts/node.sh"
#   #     # script = each.value.type == "controlplane" ? "scripts/test.sh" : "scripts/test02.sh"
#   #   }



#   provisioner "file" {
#     # source      = each.value.type == "controlplane" ? "scripts/controlplane.sh" : "scripts/node.sh"
#     source      = "scripts/"
#     destination = "/tmp"
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "printf '%s\n' \"${var.host_sudo_password}\" | sudo -p \"\" -S echo 'authenticated with sudo!'",
#       "cd /tmp",
#       "pwd",
#       "sudo chmod +x ${local.script}",
#       "sudo sh -c \"export COSMO_KUBERNETES_HOST_CONTROLPLANE=\"${each.value.type == "controlplane" ? "true" : "false"}\" && ./${local.script}\"",
#       "rm -f /tmp/terraform_*.sh",
#     ]
#   }

# }



# Copy scripts and execute them on remote hosts
resource "terraform_data" "hosts" {
  for_each = var.hosts

  connection {
    host = each.value.ip
    port = each.value.port
    user = each.value.user
  }

  provisioner "file" {
    source      = "scripts/"
    destination = "/tmp"
  }

  # Make scripts executables
  provisioner "remote-exec" {
    inline = [
      "printf '%s\n' \"${var.host_sudo_password}\" | sudo -p \"\" -S echo 'authenticated with sudo!'",
      "cd /tmp",
      "pwd",
      "sudo chmod +x kubeadm_*",
    ]
  }

  # Install controlplane
  provisioner "remote-exec" {
    inline = each.value.type == "controlplane" ? [
      "printf '%s\n' \"${var.host_sudo_password}\" | sudo -p \"\" -S echo 'authenticated with sudo!'",
      "cd /tmp",
      "pwd",
      "script='create_controlplane.sh'",
      "sudo chmod +x $script",
      "sudo sh -c \"./$script\"",
    ] : 0
  }

  # Install nodes
  provisioner "remote-exec" {
    inline = each.value.type != "controlplane" ? [
      "printf '%s\n' \"${var.host_sudo_password}\" | sudo -p \"\" -S echo 'authenticated with sudo!'",
      "cd /tmp",
      "pwd",
      "script='create_node.sh'",
      "sudo chmod +x $script",
      "sudo sh -c \"./$script\"",
    ] : 0
  }

  # Clean host
  provisioner "remote-exec" {
    inline = [
      "rm -f /tmp/terraform_*.sh",
    ]
  }
}

