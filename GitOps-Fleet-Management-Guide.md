# GitOps Fleet Management - Complete Reference Guide

## Table of Contents
1. [Overview](#overview)
2. [Architecture Concepts](#architecture-concepts)
3. [Repository Structure](#repository-structure)
4. [Core Components](#core-components)
5. [Configuration Hierarchy](#configuration-hierarchy)
6. [Deployment Models](#deployment-models)
7. [Registration Process](#registration-process)
8. [Version Management](#version-management)
9. [Step-by-Step Workflows](#step-by-step-workflows)
10. [Troubleshooting](#troubleshooting)

## Overview

The GitOps Fleet Management system is a comprehensive solution for managing multiple Kubernetes clusters using ArgoCD. It provides a flexible approach to cluster management with support for both centralized and distributed (agent) deployment models.

### Key Features
- **Multi-cluster management** with hub-and-spoke architecture
- **Flexible deployment models** (centralized vs distributed)
- **Hierarchical configuration** with tenant/environment/cluster overrides
- **Dynamic ApplicationSet generation** using wrapper pattern
- **Secure cluster registration** via AWS Secrets Manager
- **Version management** with selective deployment
- **Label-based component selection**

## Architecture Concepts

### Hub-and-Spoke Model

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                HUB CLUSTER                                     │
│  ┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────────────┐ │
│  │   ArgoCD        │    │ External Secrets │    │    AWS Secrets Manager      │ │
│  │   (GitOps       │◄───┤    Operator      │◄───┤   (Spoke Credentials)       │ │
│  │   Controller)   │    │                  │    │                             │ │
│  └─────────────────┘    └──────────────────┘    └─────────────────────────────┘ │
│           │                                                                      │
│           ▼                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │                    FLEET BOOTSTRAP PROCESS                                  │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              SPOKE CLUSTERS                                     │
│  ┌─────────────────────────┐              ┌─────────────────────────────────────┐ │
│  │   CENTRALIZED MODEL     │              │      DISTRIBUTED MODEL             │ │
│  │   (use_remote_argo:     │              │   (use_remote_argo: "true")         │ │
│  │        "false")         │              │                                     │ │
│  └─────────────────────────┘              └─────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### ApplicationSet Wrapper Pattern

The core innovation is the **application-sets chart** that acts as a dynamic template generator:

- **Wrapper Chart**: Helm chart stored in ECR that generates ApplicationSets
- **Dynamic Configuration**: Merges values from multiple hierarchical sources
- **Label-Based Selection**: Uses cluster labels to determine deployments
- **Version Control**: Manages component versions centrally

## Repository Structure

```
eks-fleet-management/
├── fleet/                          # Core GitOps definitions
│   ├── bootstrap/                  # Hub cluster ApplicationSets
│   │   ├── addons.yaml            # Manages add-on deployment
│   │   ├── resources.yaml         # Manages resource deployment  
│   │   ├── monitoring.yaml        # Manages monitoring deployment
│   │   ├── fleetv2.yaml          # Manages fleet registration
│   │   └── versions/              # Version control for components
│   │       └── applicationSets.yaml
│   └── fleet-bootstrap/           # Spoke cluster registration
│       ├── fleet-hub-external-secrets.yaml  # Main registration ApplicationSet
│       ├── fleet-members/         # Spoke cluster configurations
│       ├── members-application-sets/  # ApplicationSets for distributed model
│       └── members-init-v2/       # Initialization configs for distributed model
├── addons/                        # Configuration overrides and labels
│   ├── defaults/                  # System-wide defaults
│   ├── tenants/                   # Tenant-specific configurations
│   │   ├── defaults/              # Default tenant configurations
│   │   │   └── fleet/fleet-secret/values.yaml  # Cluster labels definition
│   │   └── tenant1/               # Specific tenant overrides
│   └── bootstrap/                 # Bootstrap-specific configs
├── resources/                     # Resource configuration overrides
├── charts/                        # Helm charts
│   ├── application-sets/          # Core ApplicationSet wrapper chart
│   ├── fleet-secret/             # Fleet secret management chart
│   └── [other charts]/           # Individual component charts
└── terraform/                     # Infrastructure as Code
    ├── hub/                       # Hub cluster Terraform
    └── spokes/                    # Spoke cluster Terraform
```

## Core Components

### 1. Fleet Bootstrap (`fleet/bootstrap`)

**Purpose**: Initialize the hub cluster with core ApplicationSets

#### Key Files:

**addons.yaml**
- Manages cluster add-ons deployment across the fleet
- Uses application-sets helm chart wrapper
- Deploys core controllers (ArgoCD, ALB, External Secrets, etc.)
- References configurations in `addons/` to override default values

**resources.yaml**
- Handles fleet-wide resource deployments
- Supports separate team management
- Independent resource lifecycle

**monitoring.yaml**
- Configures monitoring solutions across the fleet
- Example of separation by teams/responsibilities

**fleetv2.yaml**
- Manages spoke cluster registration process
- Controls cluster onboarding

### 2. Fleet Bootstrap (`fleet/fleet-bootstrap`)

**Purpose**: Handle registration and initialization of spoke clusters

#### Key Files:

**fleet-hub-external-secrets.yaml**
- Creates external secrets on hub cluster
- Pulls spoke registration from AWS Secrets Manager
- Configures tenant repository connections
- References fleet-members configurations

**fleet-members/**
- Spoke cluster configurations
- Deployment model selection
- Tenant and environment settings
- Repository access configurations

**members-application-sets/**
- Spoke cluster ApplicationSet templates
- Used in distributed ArgoCD setup
- Referenced by spoke ArgoCD instances

## Configuration Hierarchy

The system uses a **5-level configuration hierarchy** (from highest to lowest priority):

### 1. Cluster-Specific (Highest Priority)
```
addons/tenants/{tenant}/clusters/{cluster-name}/{component}/
```

### 2. Environment-Specific
```
addons/tenants/{tenant}/environments/{environment}/{component}/
```

### 3. Tenant-Specific
```
addons/tenants/{tenant}/defaults/{component}/
```

### 4. Global Tenant Defaults
```
addons/tenants/defaults/{component}/
```

### 5. System-Wide Defaults (Lowest Priority)
```
addons/defaults/{component}/
```

### Value File Resolution Example

For cluster "spoke-dev-workload1" in tenant1:

```yaml
valueFiles:
  - addons/defaults/addons.yaml                                    # System defaults
  - addons/tenants/defaults/addons.yaml                           # Global tenant defaults
  - addons/tenants/tenant1/defaults/addons.yaml                   # Tenant defaults
  - addons/tenants/tenant1/environments/dev/addons.yaml           # Environment defaults
  - addons/tenants/tenant1/clusters/spoke-dev-workload1/addons.yaml # Cluster specific
```

## Deployment Models

### Centralized Management
**Configuration**: `use_remote_argo: "false"`

**Characteristics**:
- Hub cluster's ArgoCD instance manages all resources on spoke clusters
- Single point of control and visibility
- Suitable for smaller fleets or environments requiring centralized governance

### Distributed ("Agent") Model
**Configuration**: `use_remote_argo: "true"`

**Characteristics**:
- Hub deploys ArgoCD to spoke clusters
- Spoke clusters manage their own resources
- Improved scalability for large fleets
- Reduced load on the hub cluster
- Configurable with `enable_remote_resources` and `enable_remote_addons` flags

## Registration Process

### Step-by-Step Cluster Registration

#### 1. Infrastructure Provisioning (Terraform)
```bash
# Deploy spoke cluster
cd terraform/spokes/
terraform apply

# This creates:
# - EKS cluster
# - IAM roles for cross-account access
# - AWS Secrets Manager secret with cluster credentials
# - Resource policies for hub access
```

#### 2. Create Cluster Registration Configuration
```yaml
# fleet/fleet-bootstrap/fleet-members/{hub-cluster}/{spoke-cluster}.yaml
tenant: "tenant1"
clusterName: "spoke-dev-workload1"
secretManagerSecretName: "arn:aws:secretsmanager:region:account:secret:hub-cluster/spoke-dev-workload1"

# Deployment model selection
use_remote_argo: "false"           # Centralized model
enable_remote_resources: "false"   # Hub manages resources
enable_remote_addons: "false"      # Hub manages addons
use_fleet_ack: "false"            # Don't use fleet ACK controllers
use_argocd_ingress: "false"       # Don't create ArgoCD ingress
```

#### 3. Configure Cluster Labels
```yaml
# addons/tenants/tenant1/clusters/spoke-dev-workload1/fleet-secret/values.yaml
externalSecret:
  labels:
    fleetRelease: default
    addonsRelease: release1
    monitoringRelease: default
    enable_metrics_server: "true"
    enable_external_secrets: "true"
    enable_aws_load_balancer_controller: "true"
```

#### 4. Automatic Registration Process
1. `fleet-hub-external-secrets.yaml` ApplicationSet detects new configuration
2. Creates external secret that pulls cluster credentials from AWS Secrets Manager
3. Creates ArgoCD cluster secret with appropriate labels
4. Bootstrap ApplicationSets detect new cluster and begin deployment

## Version Management

### Version Configuration
```yaml
# fleet/bootstrap/versions/applicationSets.yaml
releases:
  addons:
  - type: "default"
    chartRepo: "471112582304.dkr.ecr.eu-west-2.amazonaws.com"
    ecrChartName: "application-sets"
    version: 0.3.1
  - type: "release1"
    chartRepo: "471112582304.dkr.ecr.eu-west-2.amazonaws.com"
    ecrChartName: "application-sets"
    version: 0.3.2
  monitoring:
  - type: "default"
    version: 0.1.0
```

### Label-Based Version Selection
```yaml
# Cluster labels control which version is deployed
externalSecret:
  labels:
    addonsRelease: release1      # Uses "release1" version of addons
    monitoringRelease: default   # Uses "default" version of monitoring
```

## Step-by-Step Workflows

### Workflow 1: Adding a New Spoke Cluster

#### Prerequisites
- Hub cluster deployed and operational
- Spoke cluster created via Terraform
- Spoke credentials stored in AWS Secrets Manager

#### Steps

1. **Create Registration Configuration**
```bash
# Create the registration file
cat > fleet/fleet-bootstrap/fleet-members/hub-cluster/my-new-spoke.yaml << EOF
tenant: "tenant1"
clusterName: "my-new-spoke"
addons_repo_basepath: "addons/tenants"
resources_repo_basepath: "resources/tenants"
secretManagerSecretName: "arn:aws:secretsmanager:region:account:secret:hub-cluster/my-new-spoke"

use_remote_argo: "false"
enable_remote_resources: "false"
enable_remote_addons: "false"
use_fleet_ack: "false"
use_argocd_ingress: "false"
EOF
```

2. **Configure Cluster Labels (Optional)**
```bash
# Create cluster-specific labels
mkdir -p addons/tenants/tenant1/clusters/my-new-spoke/fleet-secret/
cat > addons/tenants/tenant1/clusters/my-new-spoke/fleet-secret/values.yaml << EOF
externalSecret:
  labels:
    fleetRelease: default
    addonsRelease: release1
    monitoringRelease: default
    enable_metrics_server: "true"
    enable_external_secrets: "true"
    enable_aws_load_balancer_controller: "true"
EOF
```

3. **Commit and Push**
```bash
git add .
git commit -m "Add new spoke cluster: my-new-spoke"
git push origin main
```

4. **Verify Registration**
```bash
# Check ArgoCD for new cluster
kubectl get secrets -n argocd | grep my-new-spoke

# Check ApplicationSet status
kubectl get applicationsets -n argocd
```

### Workflow 2: Updating Component Versions

#### Steps

1. **Update Version Configuration**
```bash
# Edit versions file
vim fleet/bootstrap/versions/applicationSets.yaml

# Add new release
releases:
  addons:
  - type: "release2"
    version: 0.4.0
```

2. **Update Cluster Labels**
```bash
# Update cluster to use new version
vim addons/tenants/tenant1/clusters/my-spoke/fleet-secret/values.yaml

# Change release
externalSecret:
  labels:
    addonsRelease: release2  # Changed from release1
```

3. **Commit and Deploy**
```bash
git add .
git commit -m "Update addons to release2 for my-spoke"
git push origin main
```

### Workflow 3: Adding Custom Configuration

#### Steps

1. **Create Tenant-Specific Override**
```bash
# Create tenant-specific addon configuration
mkdir -p addons/tenants/tenant1/defaults/addons/
cat > addons/tenants/tenant1/defaults/addons/values.yaml << EOF
# Custom configuration for tenant1
aws-load-balancer-controller:
  enabled: true
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT:role/tenant1-alb-role"
EOF
```

2. **Create Environment-Specific Override**
```bash
# Create dev environment specific configuration
mkdir -p addons/tenants/tenant1/environments/dev/addons/
cat > addons/tenants/tenant1/environments/dev/addons/values.yaml << EOF
# Dev environment specific settings
aws-load-balancer-controller:
  replicaCount: 1  # Single replica for dev
EOF
```

3. **Create Cluster-Specific Override**
```bash
# Create cluster-specific configuration
mkdir -p addons/tenants/tenant1/clusters/my-dev-cluster/addons/
cat > addons/tenants/tenant1/clusters/my-dev-cluster/addons/values.yaml << EOF
# Cluster-specific settings
aws-load-balancer-controller:
  resources:
    requests:
      memory: "128Mi"  # Lower memory for this specific cluster
EOF
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Cluster Not Appearing in ArgoCD

**Symptoms**: New cluster configuration created but cluster doesn't appear in ArgoCD

**Diagnosis**:
```bash
# Check external secrets
kubectl get externalsecrets -n argocd

# Check secret creation
kubectl get secrets -n argocd | grep cluster-

# Check ApplicationSet status
kubectl describe applicationset fleet-hub-secrets -n argocd
```

**Solutions**:
- Verify AWS Secrets Manager secret exists and is accessible
- Check IAM permissions for external-secrets operator
- Verify secret name matches exactly in configuration
- Check external-secrets operator logs

#### 2. Components Not Deploying to Spoke

**Symptoms**: Cluster registered but expected components not deploying

**Diagnosis**:
```bash
# Check cluster labels
kubectl get secret cluster-<spoke-name> -n argocd -o yaml

# Check ApplicationSet selectors
kubectl describe applicationset cluster-addons -n argocd
```

**Solutions**:
- Verify cluster labels match ApplicationSet selectors
- Check if components are enabled in cluster labels
- Verify version selectors are correct
- Check configuration hierarchy for conflicts

#### 3. Version Mismatch Issues

**Symptoms**: Wrong version of components being deployed

**Diagnosis**:
```bash
# Check versions configuration
cat fleet/bootstrap/versions/applicationSets.yaml

# Check cluster release labels
kubectl get secret cluster-<spoke-name> -n argocd -o jsonpath='{.metadata.labels}'
```

**Solutions**:
- Verify release type exists in versions configuration
- Check cluster labels specify correct release
- Ensure version selectors are enabled

#### 4. Configuration Override Not Applied

**Symptoms**: Custom configuration not being applied to cluster

**Diagnosis**:
```bash
# Check Application values
kubectl get application <app-name> -n argocd -o yaml

# Check value file paths in ApplicationSet
kubectl describe applicationset cluster-addons -n argocd
```

**Solutions**:
- Verify file paths in configuration hierarchy
- Check YAML syntax in override files
- Ensure tenant/environment/cluster names match exactly
- Verify value file precedence order

### Debugging Commands

```bash
# Check all ApplicationSets
kubectl get applicationsets -n argocd

# Check specific ApplicationSet details
kubectl describe applicationset cluster-addons -n argocd

# Check cluster secrets
kubectl get secrets -n argocd | grep cluster-

# Check external secrets status
kubectl get externalsecrets -n argocd

# Check ArgoCD applications
kubectl get applications -n argocd

# Check external-secrets operator logs
kubectl logs -n external-secrets-system deployment/external-secrets

# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-applicationset-controller
```

## Best Practices

### 1. Configuration Management
- Use the hierarchical configuration approach consistently
- Keep system-wide defaults minimal and generic
- Use tenant-specific configurations for organizational boundaries
- Apply cluster-specific overrides sparingly

### 2. Version Control
- Manage releases through the versions/applicationSets.yaml file
- Use semantic versioning for component releases
- Test new versions in development environments first
- Document version changes and their impacts

### 3. Security
- Use AWS Secrets Manager for all sensitive data
- Implement least-privilege IAM policies
- Regularly rotate credentials
- Monitor cross-account access patterns

### 4. Deployment Strategy
- Choose deployment model based on fleet size and governance requirements
- Start with centralized model for smaller fleets
- Consider distributed model for large-scale deployments
- Plan for disaster recovery scenarios

### 5. Monitoring and Observability
- Monitor ApplicationSet health and sync status
- Set up alerts for failed deployments
- Track configuration drift across clusters
- Implement logging for audit trails

## Conclusion

This GitOps Fleet Management system provides a powerful, scalable approach to managing multiple Kubernetes clusters. The combination of hierarchical configuration, label-based selection, and flexible deployment models makes it suitable for organizations of various sizes and complexity levels.

The key to success with this system is understanding the configuration hierarchy and using labels effectively to control deployments. Start simple with basic configurations and gradually add complexity as your needs grow.
