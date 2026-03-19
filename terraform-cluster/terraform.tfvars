cluster_name  = "devops"
cluster_stage = "dev"
domain_zone   = "onpremise.platform.cosmotech.com"

# Override the default naming convention
#  - false => "kob-<cluster_stage>-<cluster_name>"
#  - true  => cluster_name = the exact name that will be used
override_naming_convention = "false"

# State host can be DNS record, IP address, and must start with http:// or https://
# state_host = "http://192.168.x.x"
state_host = "https://cosmotechstates.onpremise.platform.cosmotech.com"

# DNS challenge provider where the cluster record is hosted
dns_challenge_provider = "azure"
