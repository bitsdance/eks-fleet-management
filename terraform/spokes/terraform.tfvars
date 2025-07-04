# Spoke Cluster Configuration
# Target Account: 609177035700
# Region: eu-west-2
# Direct deployment (no cross-account role needed)

# VPC Configuration
vpc_name = "eks-fleet-dev-workload-1"

# Cluster Configuration
kubernetes_version = "1.32"
enable_automode = true
tenant = "tenant1"
cluster_type = "tenant"

# Hub Configuration
hub_account_id = "140023360843"
hub_cluster_name = "hub-cluster"

# Environment Configuration
deployment_environment = "np"
environment_prefix = "dev"

# Account Configuration
accounts_config = {
  np = {
    account_id = "609177035700"
  }
}

# Node Group Configuration (for non-automode components)
managed_node_group_ami = "BOTTLEROCKET_x86_64"
managed_node_group_instance_types = ["m5.large"]

# Cluster Endpoint Configuration
eks_cluster_endpoint_public_access = true

# Domain Configuration (optional)
domain_name = ""
route53_zone_name = ""

# Observability Configuration (optional)
amp_prometheus_crossaccount_role = ""

# KMS Configuration
kms_key_admin_roles = []

# Remote spoke secret configuration
remote_spoke_secret = false

# ACK Pod Identity (use terraform for now)
enable_ack_pod_identity = false
