cluster_name    = "kubernetes"
cluster_stage   = "dev"

# Override the default naming convention
#  - false => "kob-<cluster_stage>-<cluster_name>"
#  - true  => cluster_name = the exact name that will be used
override_naming_convention = "true"

# If kubeadm is already installed, set to false
install_kubeadm = "false"

# DNS challenge provider where the cluster record is hosted
dns_challenge_provider = "azure"

state_host = "10.2.0.108"