################################################################################
# Infrastructure Variables
################################################################################

# AWS region where resources will be deployed
region = "eu-west-2"

# VPC name to be used by pipelines for data (REQUIRED)
vpc_name = "eks-fleet"

# Map of objects for per environment configuration (REQUIRED)
accounts_config = {
  dev = {
    account_id = "140023360843"
  }
  staging = {
    account_id = ""
  }
  prod = {
    account_id = ""
  }
}

# Cross-account role name for multi-account deployments (optional)
cross_account_role_name = "eks-fleet-xaccount"

# ECR account for GitOps bridge images (optional)
ecr_account = ""

# List of role ARNs to add to the KMS policy (optional)
kms_key_admin_roles = []

# Enable EFS File System
enable_efs = false

################################################################################
# Cluster Related Variables
################################################################################

# Kubernetes version (REQUIRED)
kubernetes_version = "1.31"

# Type of tenancy - "hub" for hub cluster or tenant group name for spoke
tenant = "hub"

# Fleet membership type - "hub" or "spoke" (REQUIRED)
fleet_member = "hub-cluster"

# Environment name (REQUIRED)
environment = "dev"

# Cluster name
cluster_name = "hub-cluster"

# Deploy public or private endpoint for the cluster
eks_cluster_endpoint_public_access = true

# Managed node group AMI type
managed_node_group_ami = "BOTTLEROCKET_x86_64"

# List of managed node group instance types
managed_node_group_instance_types = ["m5.large"]

# AMI version for Bottlerocket worker nodes (optional)
ami_release_version = ""

# Enable hub cluster external secrets operator
enable_hub_external_secrets = "false"

# Use ACK for pod identity instead of Terraform
enable_ack_pod_identity = false

# Enable EKS Automode
enable_automode = false

# Route53 zone name for external DNS (optional)
route53_zone_name = ""

################################################################################
# AWS Resources Configuration
################################################################################

# Resources to be created for addons
aws_resources = {
  enable_external_secrets             = true
  enable_aws_lb_controller            = true
  enable_aws_efs_csi_driver           = false
  enable_eck_stack                    = false
  enable_efs                          = false
  enable_karpenter                    = true
  enable_prometheus_scraper           = true
  enable_cni_metrics_helper           = true
  enable_aws_cloudwatch_observability = true
  enable_aws_load_balancer_controller = true
}

################################################################################
# Git Repository Variables
################################################################################

# Git credentials secret name for ArgoCD
git_creds_secret = "git-credentials"

# GitHub organization name
git_org_name = "bitsdance"

# GitOps addons repository configuration
gitops_addons_repo_name = "eks-fleet-management"
gitops_addons_repo_path = "bootstrap/"
gitops_addons_repo_base_path    = "addons"
gitops_addons_repo_revision = "main"

# GitOps fleet repository configuration
gitops_fleet_repo_name = "eks-fleet-management"
gitops_fleet_repo_path = "bootstrap/"
gitops_fleet_repo_base_path = "fleet"
gitops_fleet_repo_revision = "main"

# GitOps resources repository configuration
gitops_resources_repo_name = "eks-fleet-management"
gitops_resources_repo_path = "bootstrap/"
gitops_resources_repo_base_path = "resources"
gitops_resources_repo_revision = "main"


# fleet_member                    = “hub-cluster”

# Application set file name
appSetFileName = "applicationsets"
