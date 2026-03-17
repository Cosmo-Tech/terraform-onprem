locals {
  main_name = "kob-${var.cluster_stage}-${var.cluster_name}"
  sudo_auth = "printf '%s\n' \"${var.host_sudo_password}\" | sudo -p \"\" -S echo 'authenticated with sudo!'"
  kubeadm_init_config_values = {
    CLUSTER_NAME = local.main_name
  }
}


data "template_file" "kubeadm_init_config" {
  template = templatefile("${path.module}/kube_objects/kubeadm.config.init.yaml", local.kubeadm_init_config_values)
}


# Install Kubeadm itselft
resource "terraform_data" "kubeadm_install" {
  for_each = var.hosts

  connection {
    host  = each.value.ip
    port  = each.value.port
    user  = each.value.user
    agent = true
  }

  provisioner "file" {
    source      = "scripts/"
    destination = "/tmp"
  }

  # Make scripts executables
  provisioner "remote-exec" {
    inline = [
      "${local.sudo_auth}",
      "cd /tmp",
      "sudo chmod +x kubeadm_*",
    ]
  }

  # Install Kubeadm itself on all hosts (the binaries & required packages)
  provisioner "remote-exec" {
    inline = [
      "${local.sudo_auth}",
      "cd /tmp",
      "script='kubeadm_install.sh'",
      "sudo chmod +x $script",
      "sudo sh -c \"./$script\"",
    ]
  }
}


# Configure Kubeadm controlplane
resource "terraform_data" "kubeadm_config_controlplane" {
  for_each = var.hosts

  connection {
    host  = each.value.ip
    port  = each.value.port
    user  = each.value.user
    agent = true
  }

  # Send kubeadm init config file to controlplane host
  provisioner "file" {
    content     = data.template_file.kubeadm_init_config.rendered
    destination = "/tmp/kubeadm.config.init.yaml"
  }

  # Install controlplane on host with type "controlplane" from terraform.tfvars
  provisioner "remote-exec" {
    inline = each.value.type == "controlplane" ? [
      "${local.sudo_auth}",
      "cd /tmp",
      "script='kubeadm_create_controlplane.sh'",
      "sudo chmod +x $script",
      "sudo sh -c \"./$script\"",
    ] : ["echo ''"]
  }

  depends_on = [terraform_data.kubeadm_install]
}


# Configure Kubeadm nodes
resource "terraform_data" "kubeadm_config_nodes" {
  for_each = var.hosts

  connection {
    host  = each.value.ip
    port  = each.value.port
    user  = each.value.user
    agent = true
  }

  # Install nodes on hosts without type "controlplane" from terraform.tfvars
  provisioner "remote-exec" {
    inline = each.value.type != "controlplane" ? [
      "${local.sudo_auth}",
      "cd /tmp",
      "script='kubeadm_create_node.sh'",
      "sudo chmod +x $script",
      "sudo sh -c \"./$script\"",
    ] : ["echo ''"]
  }

  depends_on = [terraform_data.kubeadm_config_controlplane]
}


# Get kubeconfig file
resource "terraform_data" "get_kubeconfig" {
  for_each = var.hosts

  connection {
    host  = each.value.ip
    port  = each.value.port
    user  = each.value.user
    agent = true
  }

  # Get kubeconfig file
  provisioner "remote-exec" {
    inline = each.value.type == "controlplane" ? [
      "${local.sudo_auth}",
      "cat /etc/kubernetes/admin.conf",
    ] : ["echo ''"]
  }

  depends_on = [terraform_data.kubeadm_config_nodes]
}


# # Clean hosts
# resource "terraform_data" "cleaning" {
#   for_each = var.hosts

#   connection {
#     host = each.value.ip
#     port = each.value.port
#     user = each.value.user
#     agent  = true
#   }

#   # Clean hosts
#   provisioner "remote-exec" {
#     inline = [
#       "${local.sudo_auth}",
#       "sudo rm -f /tmp/terraform_*.sh",
#     ]
#   }

#   depends_on = [ terraform_data.kubeadm_config ]
# }


# # Reboot host
# resource "terraform_data" "host_reboot_final" {
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
#       "${local.sudo_auth}",
#       "echo 'rebooting host'",
#       "sudo init 6",
#     ]
#   }

#   depends_on = [ terraform_data.get_kubeconfig ]
# }
