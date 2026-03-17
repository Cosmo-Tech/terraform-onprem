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



# Install Kubeadm
resource "terraform_data" "kubeadm_install" {
  for_each = var.hosts

  connection {
    host = each.value.ip
    port = each.value.port
    user = each.value.user
    agent  = true
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
      "sudo chmod +x kubeadm_*",
    ]
  }

  # Install kubeadm itself on all hosts (the binaries & required packages)
  provisioner "remote-exec" {
    inline = [
      "printf '%s\n' \"${var.host_sudo_password}\" | sudo -p \"\" -S echo 'authenticated with sudo!'",
      "cd /tmp",
      "script='kubeadm_install.sh'",
      "sudo chmod +x $script",
      "sudo sh -c \"./$script\"",
    ]
  }
}


# # Reboot host
# resource "terraform_data" "host_reboot" {
#   for_each = var.hosts

#   connection {
#     host = each.value.ip
#     port = each.value.port
#     user = each.value.user
#     agent  = true
#   }

#   # Reboot host
#   provisioner "remote-exec" {
#     inline = [
#       "printf '%s\n' \"${var.host_sudo_password}\" | sudo -p \"\" -S echo 'authenticated with sudo!'",
#       "sudo init 6",
#     ]
#   }

#   depends_on = [ terraform_data.kubeadm_install ]
# }


# Configure Kubeadm controlplane & nodes
resource "terraform_data" "kubeadm_config" {
  for_each = var.hosts

  connection {
    host = each.value.ip
    port = each.value.port
    user = each.value.user
    agent  = true
  }

  # Install controlplane on given the host with type "controlplane" from terraform.tfvars
  provisioner "remote-exec" {
    inline = each.value.type == "controlplane" ? [
      "printf '%s\n' \"${var.host_sudo_password}\" | sudo -p \"\" -S echo 'authenticated with sudo!'",
      "cd /tmp",
      "script='kubeadm_create_controlplane.sh'",
      "sudo chmod +x $script",
      "sudo sh -c \"./$script\"",
    ] : ["echo ''"]
  }

  # Install nodes on given the host without type "controlplane" from terraform.tfvars
  provisioner "remote-exec" {
    inline = each.value.type != "controlplane" ? [
      "printf '%s\n' \"${var.host_sudo_password}\" | sudo -p \"\" -S echo 'authenticated with sudo!'",
      "cd /tmp",
      "script='kubeadm_create_node.sh'",
      "sudo chmod +x $script",
      "sudo sh -c \"./$script\"",
    ] : ["echo ''"]
  }

  depends_on = [ terraform_data.kubeadm_install ]
}


# Clean hosts
resource "terraform_data" "cleaning" {
  for_each = var.hosts

  connection {
    host = each.value.ip
    port = each.value.port
    user = each.value.user
    agent  = true
  }

  # Clean host
  provisioner "remote-exec" {
    inline = [
      "printf '%s\n' \"${var.host_sudo_password}\" | sudo -p \"\" -S echo 'authenticated with sudo!'",
      "cd /tmp",
      "sudo rm -f /tmp/terraform_*.sh",
    ]
  }

  depends_on = [ terraform_data.kubeadm_config ]
}


# Reboot host
resource "terraform_data" "host_reboot_final" {
  for_each = var.hosts

  connection {
    host = each.value.ip
    port = each.value.port
    user = each.value.user
    agent  = true
  }

  # Reboot host
  provisioner "remote-exec" {
    inline = [
      "printf '%s\n' \"${var.host_sudo_password}\" | sudo -p \"\" -S echo 'authenticated with sudo!'",
      "echo 'rebooting host'",
      "sudo init 6",
    ]
  }

  depends_on = [ terraform_data.kubeadm_config ]
}
