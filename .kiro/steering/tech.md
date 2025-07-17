# Technology Stack & Build System

## Core Technologies
- **Kubernetes**: Container orchestration platform
- **ArgoCD**: GitOps continuous delivery tool for Kubernetes
- **Helm**: Package manager for Kubernetes
- **AWS Services**:
  - EKS (Elastic Kubernetes Service)
  - Secrets Manager
  - IAM (Identity and Access Management)
  - ECR (Elastic Container Registry)

## Key Components
- **ApplicationSets**: ArgoCD resource for managing multiple applications
- **External Secrets Operator**: Manages secrets from external sources
- **Pod Identity**: AWS IAM roles for service accounts
- **Terraform**: Infrastructure as Code for cluster provisioning

## Repository Structure
- **Helm Charts**: Located in `/charts/` directory
- **Fleet Configuration**: Located in `/fleet/` directory
- **Addons Configuration**: Located in `/addons/` directory
- **Resources Configuration**: Located in `/resources/` directory
- **Infrastructure Code**: Located in `/terraform/` directory

## Common Commands

### Terraform Commands
```bash
# Deploy hub cluster
cd terraform/hub/
terraform init
terraform plan
terraform apply

# Deploy spoke cluster
cd terraform/spokes/
terraform init
terraform plan
terraform apply
```

### ArgoCD Commands
```bash
# Check ApplicationSet status
kubectl get applicationsets -n argocd

# Check Application status
kubectl get applications -n argocd

# Check cluster registration
kubectl get secrets -n argocd | grep cluster-

# Check external secrets
kubectl get externalsecrets -n argocd
```

### Cluster Registration
```bash
# Create cluster registration file
# Path: fleet/fleet-bootstrap/fleet-members/{hub-cluster}/{spoke-cluster}.yaml

# Configure cluster labels
# Path: addons/tenants/{tenant}/clusters/{cluster}/fleet-secret/values.yaml
```

## Version Management
- Version configuration in `fleet/bootstrap/versions/applicationSets.yaml`
- Cluster labels in `addons/tenants/{tenant}/defaults/fleet/fleet-secret/values.yaml`
- Component-specific versions in respective release files