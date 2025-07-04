# EKS Fleet Management Deployment Session Context

## Project Overview
- **Project**: EKS Fleet Management with Hub-Spoke Architecture
- **Location**: `/Users/sharmcra/Library/CloudStorage/WorkDocsDrive-Documents/AllProjectsInternal/mkpattern/eks-fleet-management/terraform`
- **Architecture**: GitOps-based fleet management with centralized ArgoCD

## Account Configuration
- **Hub Account**: 140023360843 (hosts central ArgoCD and shared services)
- **Spoke Account**: 609177035700 (target for spoke cluster deployment)
- **Current User**: `sharmcra+controltower@amazon.co.uk` via AWS SSO
- **Region**: eu-west-2

## Hub Cluster Status
- **Status**: Successfully deployed and running
- **Cluster Name**: hub-cluster
- **Location**: terraform/hub directory
- **Key Components**: ArgoCD, shared services, centralized monitoring

## Spoke Cluster Configuration
- **Target Account**: 609177035700
- **VPC Name**: eks-fleet-dev-workload-1
- **Cluster Name**: spoke-np (spoke-{workspace})
- **Kubernetes Version**: 1.32
- **Auto Mode**: Enabled
- **Tenant**: tenant1
- **Environment**: np (non-production)

## Infrastructure Created

### VPC Infrastructure (Cost-Optimized)
- **VPC ID**: vpc-0268573597625825f
- **CIDR**: 10.0.0.0/16
- **Cost Optimization**: Single NAT Gateway instead of 3 (saves ~$90-120/month)

#### Subnets Created:
**Private Subnets** (for EKS worker nodes):
- private-eu-west-2a: subnet-000365a58dba77c56 (10.0.1.0/24)
- private-eu-west-2b: subnet-06d683d65f30553f8 (10.0.2.0/24)
- private-eu-west-2c: subnet-07d5582e9977e78f4 (10.0.3.0/24)

**Intra Subnets** (for EKS control plane):
- intra-eu-west-2a: subnet-07337125285b1a07a (10.0.51.0/24)
- intra-eu-west-2b: subnet-053545f076099195e (10.0.52.0/24)
- intra-eu-west-2c: subnet-0ce55352911ce7e21 (10.0.53.0/24)

**Public Subnets** (for NAT gateway and load balancers):
- public-eu-west-2a: subnet-03c34d46db0186c50 (10.0.101.0/24)
- public-eu-west-2b: subnet-02eafcf3ab5dc411a (10.0.102.0/24)
- public-eu-west-2c: subnet-0aea44ffccf00dd65 (10.0.103.0/24)

#### Networking Components:
- **Internet Gateway**: igw-08fe4af7bc98b58a2
- **NAT Gateway**: nat-0b2d7a7e84505b5bf (single, cost-optimized)
- **Elastic IP**: eipalloc-0edae18ad39d67145
- **Route Tables**: Configured for public/private routing

## Terraform Configuration

### Backend Configuration
- **S3 Bucket**: spoke-account-stack-tfstatebackendbucket-strsegv4597z
- **Region**: eu-west-1 (bucket location)
- **Key**: spokes/terraform.tfstate
- **Workspace**: np

### Provider Versions
- **AWS Provider**: 5.99.1 (pinned for ARM64 Mac compatibility)
- **Helm Provider**: >= 2.10.1
- **Kubernetes Provider**: 2.22.0

### Key Configuration Files
- **terraform.tfvars**: Spoke cluster configuration
- **providers.tf**: Provider configurations with cross-account role
- **versions.tf**: Provider version constraints

## Cross-Account Integration

### Required Role
- **Role ARN**: arn:aws:iam::140023360843:role/cross-account-role
- **Purpose**: Allow spoke account to access hub services
- **Current Status**: Missing/not accessible

### Cross-Account Dependencies
1. **ArgoCD Integration**: Spoke registers with hub ArgoCD
2. **Centralized Observability**: Access to shared AMP workspace
3. **Shared Configuration**: Read SSM parameters from hub
4. **GitOps Management**: Hub ArgoCD manages spoke deployments

## GitOps Configuration

### Repository Variables (from hub terraform.tfvars)
```hcl
gitops_addons_repo_path = "bootstrap"           # Path within repo
gitops_addons_repo_base_path = "addons"        # Base directory for addons
gitops_addons_repo_revision = "live"           # Git branch/tag to use
```

### Usage
- **GitOps Bridge Bootstrap**: Configures ArgoCD bootstrap process
- **Hub Cluster Secret**: Stored in metadata for spoke cluster access
- **Addon Management**: Tells ArgoCD where to find addon configurations

## Current Status

### Completed
✅ Hub cluster deployed and running
✅ VPC infrastructure created (cost-optimized)
✅ Terraform initialized with S3 backend
✅ Workspace created (np)
✅ Terraform plan successful (55 resources to create)
✅ **ArgoCD Applications Issue Fixed** - Updated cluster secret label from `fleet_member=hub` to `fleet_member=hub-cluster`
✅ **ArgoCD Applications Now Visible** - ApplicationSet successfully generating applications
✅ **AWS Credentials Refreshed** - New session token active for hub account (140023360843)
✅ **Terraform Detects Manual Fix** - Terraform plan shows the fleet_member label change
✅ **Spoke Analysis Complete** - Identified cross-account role requirement

### ArgoCD Fix Applied (July 3, 2025)
**Issue**: ArgoCD ApplicationSet was looking for clusters with label `fleet_member: hub-cluster` but cluster secret had `fleet_member: hub`
**Quick Fix Applied**: `kubectl label secret hub-cluster -n argocd fleet_member=hub-cluster --overwrite`
**Root Cause**: Mismatch between terraform.tfvars (`fleet_member = "hub"`) and ApplicationSet selector in bootstrap/applicationsets.yaml
**Status**: ✅ **WORKING** - Applications now visible in ArgoCD UI
**Terraform Status**: Detects the change and wants to sync the configuration

### Cross-Account Architecture Analysis (July 3, 2025)
**Hub Account (140023360843)**:
- ArgoCD pod identity can assume `*-argocd-spoke` roles in any account
- External Secrets pod identity can read secrets from spoke accounts  
- SSM parameters store the hub's pod identity role ARNs:
  - `/hub-cluster/argocd-hub-role`
  - `/hub-cluster/external-secret-role`

**Spoke Account (609177035700)**:
- Creates role named `${cluster_name}-argocd-spoke` (e.g., `spoke-np-argocd-spoke`)
- This role trusts the hub's ArgoCD pod identity role
- Creates secret with cluster configuration that hub's External Secrets can read
- Sets up KMS key and secret policies for cross-account access

### Current Issue - Cross-Account Role Missing
**Problem**: Spoke configuration tries to read SSM parameters from hub using `aws.shared-services` provider
**Provider Configuration**: 
```hcl
provider "aws" {
  alias  = "shared-services"
  region = "eu-west-2"
  assume_role {
    role_arn     = "arn:aws:iam::140023360843:role/cross-account-role"
    session_name = "shared-services"
  }
}
```
**Issue**: Role `arn:aws:iam::140023360843:role/cross-account-role` doesn't exist yet

### Pending Issues
❌ **Cross-Account Role Missing** - Need to create `arn:aws:iam::140023360843:role/cross-account-role` in hub account
❌ **AWS Credentials Expired** - Both hub and spoke account credentials need refresh
❌ **Spoke Cluster Not Deployed** - Blocked by missing cross-account role
❌ **Terraform Configuration Fix**: Need to update terraform.tfvars fleet_member value permanently when network is stable

### Next Steps Required (When You Return)
1. **Refresh Hub Account Credentials** - Get fresh credentials for hub account (140023360843)
2. **Create Cross-Account Role** - Deploy the cross-account role in hub account with these permissions:
   - Allow spoke account (609177035700) to assume it
   - Read SSM parameters: `/hub-cluster/argocd-hub-role`, `/hub-cluster/external-secret-role`
   - Read hub cluster secrets and EKS cluster info
3. **Refresh Spoke Account Credentials** - Get fresh credentials for spoke account (609177035700)
4. **Deploy Spoke Cluster** - Run terraform apply in spokes directory
5. **Verify Cross-Account Integration** - Ensure spoke cluster registers with hub ArgoCD
6. **Update Terraform Configuration**: Change `fleet_member = "hub"` to `fleet_member = "hub-cluster"` in hub terraform.tfvars

### Cross-Account Role Configuration Needed
**Location**: `/terraform/hub/cross-account.tf`
**Role Name**: `cross-account-role`
**Trust Policy**: Allow spoke account (609177035700) to assume
**Permissions Needed**:
- `ssm:GetParameter*` on `/hub-cluster/*`
- `secretsmanager:GetSecretValue` on hub cluster secret
- `eks:DescribeCluster` on hub cluster

### File Locations
- **Hub Directory**: `/Users/sharmcra/Library/CloudStorage/WorkDocsDrive-Documents/AllProjectsInternal/mkpattern/eks-fleet-management/terraform/hub`
- **Spokes Directory**: `/Users/sharmcra/Library/CloudStorage/WorkDocsDrive-Documents/AllProjectsInternal/mkpattern/eks-fleet-management/terraform/spokes`
- **Current Workspace**: `np` (non-production)
- **Spoke Configuration**: `terraform.tfvars` configured for tenant1, cluster type tenant, automode enabled

## Architecture Benefits
- **Centralized GitOps**: Single ArgoCD instance manages all clusters
- **Cost Optimization**: Shared services, single NAT gateway
- **Security**: Cross-account isolation with controlled access
- **Scalability**: Easy to add more spoke clusters
- **Observability**: Centralized monitoring and logging

## Key Commands Used
```bash
# Navigate to spokes directory
cd /Users/sharmcra/Library/CloudStorage/WorkDocsDrive-Documents/AllProjectsInternal/mkpattern/eks-fleet-management/terraform/spokes

# Initialize Terraform
terraform init -backend-config="bucket=spoke-account-stack-tfstatebackendbucket-strsegv4597z" -backend-config="key=spokes/terraform.tfstate" -backend-config="region=eu-west-1"

# Create workspace
terraform workspace new np

# Plan deployment
terraform plan
```

## Files Modified/Created
- `../spokes/terraform.tfvars`: Spoke cluster configuration
- `../spokes/providers.tf`: Updated for cross-account access
- `../spokes/versions.tf`: Provider version constraints
- VPC infrastructure created via AWS CLI scripts (later cleaned up)

## Cost Considerations
- **Optimization Applied**: Single NAT Gateway instead of 3
- **Monthly Savings**: ~$90-120 USD
- **Trade-off**: Reduced availability (single AZ NAT) for cost savings in dev environment

This context captures the complete state of our EKS Fleet Management deployment session, including all configurations, infrastructure created, and current blockers.
