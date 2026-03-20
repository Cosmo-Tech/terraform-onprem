locals {
  main_name               = var.override_naming_convention == true ? var.cluster_name : "kob-${var.cluster_stage}-${var.cluster_name}"
  command_auth_sudo       = "printf '%s\n' \"${var.host_sudo_password}\" | sudo -p \"\" -S echo 'authenticated with sudo!'"
  kubeadm_controlplane_ip = [for host in var.hosts : host if host.type == "controlplane"][0].ip
  kubeadm_join_token      = "${random_string.kubeadm_join_token_id.result}.${random_string.kubeadm_join_token_secret.result}"
  kubeadm_init_config_values = {
    CLUSTER_NAME       = local.main_name
    CLUSTER_JOIN_TOKEN = local.kubeadm_join_token
  }

  ssh_agent        = true
  dir_tmp          = "/tmp"
  triggers_replace = [timestamp()]
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

  depends_on = [local.kubeadm_init_config_values]
}


# Send scripts on remotes hosts
resource "terraform_data" "send_scripts" {
  for_each = var.hosts

  triggers_replace = local.triggers_replace

  connection {
    host  = each.value.ip
    port  = each.value.port
    user  = each.value.user
    agent = local.ssh_agent
  }

  provisioner "remote-exec" {
    inline = ["mkdir -p ${local.dir_tmp}"]
  }

  # provisioner "file" {
  #   source      = "${path.module}/scripts/kubeadm_create_controlplane.sh"
  #   destination = "${local.dir_tmp}/kubeadm_create_controlplane.sh"
  # }

  # provisioner "file" {
  #   source      = "${path.module}/scripts/kubeadm_install.sh"
  #   destination = "${local.dir_tmp}/kubeadm_install.sh"
  # }

  # provisioner "file" {
  #   source      = "${path.module}/scripts/longhorn_requirements.sh"
  #   destination = "${local.dir_tmp}/longhorn_requirements.sh"
  # }

  provisioner "file" {
    source      = "${path.module}/scripts/"
    destination = local.dir_tmp
  }

  depends_on = [data.template_file.kubeadm_init_config]
}


# Run requirements scripts on all hosts
resource "terraform_data" "scripts_requirements" {
  for_each = var.hosts

  triggers_replace = local.triggers_replace

  connection {
    host  = each.value.ip
    port  = each.value.port
    user  = each.value.user
    agent = local.ssh_agent
  }

  # Configure required firewall on all hosts
  provisioner "remote-exec" {
    inline = [
      "${local.command_auth_sudo}",
      "cd ${local.dir_tmp}",
      "script='requirements_firewall.sh'",
      "sudo chmod +x $script",
      "sudo sh -c \"./$script\"",
    ]
  }

  # Longhorn requirements on all hosts (required packages)
  # https://longhorn.io/docs/1.11.1/deploy/install/#installation-requirements
  provisioner "remote-exec" {
    inline = [
      "${local.command_auth_sudo}",
      "cd ${local.dir_tmp}",
      "script='requirements_longhorn.sh'",
      "sudo chmod +x $script",
      "sudo sh -c \"./$script\"",
    ]
  }

  depends_on = [terraform_data.send_scripts]
}


# Install Kubeadm itself on all hosts (the binaries & required packages)
resource "terraform_data" "kubeadm_install" {
  for_each = var.hosts

  triggers_replace = local.triggers_replace

  connection {
    host  = each.value.ip
    port  = each.value.port
    user  = each.value.user
    agent = local.ssh_agent
  }

  # Install Kubeadm itself on all hosts (the binaries & required packages)
  provisioner "remote-exec" {
    inline = [
      "${local.command_auth_sudo}",
      "cd ${local.dir_tmp}",
      "script='kubeadm_install.sh'",
      "sudo chmod +x $script",
      "sudo sh -c \"./$script\"",
    ]
  }

  depends_on = [terraform_data.send_scripts]
}


# Configure Kubeadm controlplane
resource "terraform_data" "kubeadm_controlplane" {
  for_each = { for key, value in var.hosts : key => value if value.type == "controlplane" }

  triggers_replace = local.triggers_replace

  connection {
    host  = each.value.ip
    port  = each.value.port
    user  = each.value.user
    agent = local.ssh_agent
  }

  # Send Kubeadm init config file to controlplane host
  provisioner "file" {
    content     = data.template_file.kubeadm_init_config.rendered
    destination = "${local.dir_tmp}/kubeadm.config.init.yaml"
  }

  # Install controlplane on host with type "controlplane" from terraform.tfvars
  provisioner "remote-exec" {
    inline = [
      "${local.command_auth_sudo}",
      "cd ${local.dir_tmp}",
      "script='kubeadm_create_controlplane.sh'",
      "sudo chmod +x $script",
      "sudo sh -c \"./$script\"",
    ]
  }

  depends_on = [terraform_data.kubeadm_install]
}


# Add nodes to the kubeadm cluster
resource "terraform_data" "kubeadm_nodes" {
  for_each = { for key, value in var.hosts : key => value if value.type != "controlplane" }

  triggers_replace = local.triggers_replace

  connection {
    host  = each.value.ip
    port  = each.value.port
    user  = each.value.user
    agent = local.ssh_agent
  }

  provisioner "remote-exec" {
    inline = [
      "${local.command_auth_sudo}",
      "if [ -f /etc/kubernetes/kubelet.conf ]; then",
      "echo 'info: this node is already in cluster ${local.main_name}, skipping'",
      "exit 0",
      "fi",
      "sudo kubeadm join ${local.kubeadm_controlplane_ip}:6443 --token ${local.kubeadm_join_token} --discovery-token-unsafe-skip-ca-verification"
    ]
  }

  depends_on = [terraform_data.kubeadm_controlplane]
}


# Get kubeconfig file
resource "terraform_data" "get_kubeconfig" {
  for_each = { for key, value in var.hosts : key => value if value.type == "controlplane" }

  triggers_replace = local.triggers_replace

  provisioner "local-exec" {
    command = "echo '' > ${local.dir_tmp}/kubeconfig_${each.key}.yaml && ssh -o StrictHostKeyChecking=no -p ${each.value.port} ${each.value.user}@${each.value.ip} 'echo \"${var.host_sudo_password}\" | sudo -S cat /etc/kubernetes/admin.conf' > ${local.dir_tmp}/kubeconfig_${each.key}.yaml"
  }

  depends_on = [terraform_data.kubeadm_controlplane]
}


# # Reboot host
# resource "terraform_data" "host_reboot_final" {
#   for_each = var.hosts

#   triggers_replace = local.triggers_replace

#   connection {
#     host  = each.value.ip
#     port  = each.value.port
#     user  = each.value.user
#     agent = true
#   }

#   # Reboot host
#   provisioner "remote-exec" {
#     inline = [
#       "${local.command_auth_sudo}",
#       "echo 'rebooting host'",
#       "sudo init 6",
#     ]
#   }

#   depends_on = [terraform_data.get_kubeconfig]
# }
