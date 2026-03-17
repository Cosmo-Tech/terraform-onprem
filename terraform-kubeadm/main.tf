locals {
  main_name               = "kob-${var.cluster_stage}-${var.cluster_name}"
  command_auth_sudo       = "printf '%s\n' \"${var.host_sudo_password}\" | sudo -p \"\" -S echo 'authenticated with sudo!'"
  kubeadm_controlplane_ip = [for host in var.hosts : host if host.type == "controlplane"][0].ip
  kubeadm_join_token      = "${random_string.kubeadm_join_token_id.result}.${random_string.kubeadm_join_token_secret.result}"
  kubeadm_init_config_values = {
    CLUSTER_NAME       = local.main_name
    CLUSTER_JOIN_TOKEN = local.kubeadm_join_token
  }
}

# Generate a token that will be used for Kubeadm nodes to join the cluster
resource "random_string" "kubeadm_join_token_id" {
  # Must be 6 char
  length  = 6
  special = false
  upper   = false
}
resource "random_string" "kubeadm_join_token_secret" {
  # Must be 16 char
  length  = 16
  special = false
  upper   = false
}




data "template_file" "kubeadm_init_config" {
  template = templatefile("${path.module}/kube_objects/kubeadm.config.init.yaml", local.kubeadm_init_config_values)
}


# Install Kubeadm itself on all hosts (the binaries & required packages)
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
      "${local.command_auth_sudo}",
      "cd /tmp",
      "sudo chmod +x kubeadm_*",
    ]
  }

  # Install Kubeadm itself on all hosts (the binaries & required packages)
  provisioner "remote-exec" {
    inline = [
      "${local.command_auth_sudo}",
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
      "${local.command_auth_sudo}",
      "cd /tmp",
      "script='kubeadm_create_controlplane.sh'",
      "sudo chmod +x $script",
      "sudo sh -c \"./$script\"",
    ] : ["echo ''"]
  }

  depends_on = [terraform_data.kubeadm_install]
}


# # Configure Kubeadm nodes
# resource "terraform_data" "kubeadm_config_nodes" {
#   for_each = var.hosts

#   connection {
#     host  = each.value.ip
#     port  = each.value.port
#     user  = each.value.user
#     agent = true
#   }

#   # Install nodes on hosts without type "controlplane" from terraform.tfvars
#   provisioner "remote-exec" {
#     inline = each.value.type != "controlplane" ? [
#       "${local.command_auth_sudo}",
#       "cd /tmp",
#       "script='kubeadm_create_node.sh'",
#       "sudo chmod +x $script",
#       "sudo sh -c \"./$script\"",
#     ] : ["echo ''"]
#   }

#   depends_on = [terraform_data.kubeadm_config_controlplane]
# }


# # Get kubeconfig file
# resource "terraform_data" "get_kubeconfig" {
#   for_each = var.hosts

#   connection {
#     host  = each.value.ip
#     port  = each.value.port
#     user  = each.value.user
#     agent = true
#   }

#   # Get kubeconfig file
#   provisioner "remote-exec" {
#     inline = each.value.type == "controlplane" ? [
#       "${local.command_auth_sudo}",
#       "sudo cat /etc/kubernetes/admin.conf",
#     ] : ["echo ''"]
#   }

#   depends_on = [terraform_data.kubeadm_config_controlplane]
# }


# Add nodes to the kubeadm cluster
resource "terraform_data" "kubeadm_nodes" {
  for_each = { for key, value in var.hosts : key => value if value.type != "controlplane" }

  connection {
    host  = each.value.ip
    user  = each.value.user
    agent = true
  }

  provisioner "remote-exec" {
    inline = [
      "if [ -f /etc/kubernetes/kubelet.conf ]; then",
      "  echo 'info: node already joined, skipping...'",
      "  exit 0",
      "fi",
      "sudo kubeadm join ${local.kubeadm_controlplane_ip}:6443 --token ${local.kubeadm_join_token} --discovery-token-unsafe-skip-ca-verification"
    ]
  }

  depends_on = [
    terraform_data.kubeadm_config_controlplane,
  ]
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
#       "${local.command_auth_sudo}",
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
#       "${local.command_auth_sudo}",
#       "echo 'rebooting host'",
#       "sudo init 6",
#     ]
#   }

#   depends_on = [ terraform_data.get_kubeconfig ]
# }
