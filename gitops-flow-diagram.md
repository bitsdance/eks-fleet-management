# GitOps Fleet Management Flow Diagram

## High-Level Architecture Flow

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
│  │                                                                             │ │
│  │  1. fleet-hub-external-secrets.yaml (ApplicationSet)                       │ │
│  │     ├── Reads fleet-members/*.yaml configurations                          │ │
│  │     ├── Pulls spoke cluster credentials from AWS Secrets Manager          │ │
│  │     ├── Creates ArgoCD cluster secrets with labels                         │ │
│  │     └── Registers spoke clusters in ArgoCD                                 │ │
│  │                                                                             │ │
│  │  2. Bootstrap ApplicationSets (fleet/bootstrap/)                            │ │
│  │     ├── addons.yaml     - Manages cluster add-ons                          │ │
│  │     ├── resources.yaml  - Manages fleet resources                          │ │
│  │     ├── monitoring.yaml - Manages monitoring stack                         │ │
│  │     └── fleetv2.yaml    - Manages fleet registration                       │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              SPOKE CLUSTERS                                     │
│                                                                                 │
│  ┌─────────────────────────┐              ┌─────────────────────────────────────┐ │
│  │   CENTRALIZED MODEL     │              │      DISTRIBUTED MODEL             │ │
│  │   (use_remote_argo:     │              │   (use_remote_argo: "true")         │ │
│  │        "false")         │              │                                     │ │
│  │                         │              │  ┌─────────────────────────────────┐ │ │
│  │  Hub ArgoCD directly    │              │  │        ArgoCD Instance          │ │ │
│  │  manages spoke cluster  │              │  │     (Deployed by Hub)           │ │ │
│  │  resources              │              │  │                                 │ │ │
│  │                         │              │  │  ├── External Secrets Operator  │ │ │
│  │  ┌─────────────────────┐│              │  │  ├── ApplicationSets from       │ │ │
│  │  │   Deployed by Hub   ││              │  │  │   members-application-sets/   │ │ │
│  │  │   ├── Add-ons       ││              │  │  └── Self-manages based on      │ │ │
│  │  │   ├── Resources     ││              │  │      enable_remote_* flags      │ │ │
│  │  │   └── Monitoring    ││              │  └─────────────────────────────────┘ │ │
│  │  └─────────────────────┘│              │                                     │ │
│  └─────────────────────────┘              └─────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Detailed Component Flow

### 1. Repository Structure and Purpose

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
```

### 2. ApplicationSet Wrapper Pattern

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        APPLICATION-SETS CHART PATTERN                          │
│                                                                                 │
│  The application-sets chart acts as a "wrapper" that:                          │
│                                                                                 │
│  1. Takes configuration from multiple sources:                                  │
│     ├── Default values from the chart itself                                   │
│     ├── Version-specific values from versions/applicationSets.yaml             │
│     ├── Tenant-specific overrides from addons/tenants/                         │
│     └── Cluster-specific overrides from the hierarchy                          │
│                                                                                 │
│  2. Generates ApplicationSets dynamically based on:                            │
│     ├── Cluster labels (selectors)                                             │
│     ├── Component enablement flags                                             │
│     ├── Version selectors                                                      │
│     └── Deployment model (centralized vs distributed)                          │
│                                                                                 │
│  3. Merges values using hierarchical precedence:                               │
│     ├── System defaults (lowest priority)                                      │
│     ├── Tenant defaults                                                        │
│     ├── Environment-specific                                                   │
│     └── Cluster-specific (highest priority)                                    │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 3. Cluster Registration and Label Flow

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           CLUSTER REGISTRATION FLOW                            │
│                                                                                 │
│  Step 1: Terraform creates spoke cluster and stores credentials in AWS SM      │
│           │                                                                     │
│           ▼                                                                     │
│  Step 2: Create fleet-members/{hub-cluster}/{spoke-cluster}.yaml               │
│           │                                                                     │
│           ▼                                                                     │
│  Step 3: fleet-hub-external-secrets.yaml ApplicationSet triggers               │
│           │                                                                     │
│           ├── Reads fleet-members configuration                                 │
│           ├── Pulls cluster credentials from AWS Secrets Manager               │
│           ├── Applies labels from addons/tenants/.../fleet-secret/values.yaml  │
│           └── Creates ArgoCD cluster secret                                     │
│           │                                                                     │
│           ▼                                                                     │
│  Step 4: Bootstrap ApplicationSets detect new cluster via labels               │
│           │                                                                     │
│           ├── addons.yaml matches clusters with addonsRelease label            │
│           ├── resources.yaml matches clusters with resourcesRelease label      │
│           └── monitoring.yaml matches clusters with monitoringRelease label    │
│           │                                                                     │
│           ▼                                                                     │
│  Step 5: Components deployed based on:                                         │
│           ├── Cluster labels (what to deploy)                                  │
│           ├── Version selectors (which version to deploy)                      │
│           ├── Deployment model (where to deploy from)                          │
│           └── Configuration hierarchy (how to configure)                       │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 4. Configuration Hierarchy Resolution

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        CONFIGURATION HIERARCHY FLOW                            │
│                                                                                 │
│  When deploying a component to cluster "spoke-dev-workload1" in tenant1:       │
│                                                                                 │
│  1. System Defaults (Base Layer)                                               │
│     └── addons/defaults/{component}/                                            │
│                                                                                 │
│  2. Global Tenant Defaults                                                     │
│     └── addons/tenants/defaults/{component}/                                    │
│                                                                                 │
│  3. Specific Tenant Defaults                                                   │
│     └── addons/tenants/tenant1/defaults/{component}/                           │
│                                                                                 │
│  4. Environment-Specific (if applicable)                                       │
│     └── addons/tenants/tenant1/environments/dev/{component}/                   │
│                                                                                 │
│  5. Cluster-Specific (Highest Priority)                                        │
│     └── addons/tenants/tenant1/clusters/spoke-dev-workload1/{component}/       │
│                                                                                 │
│  Values are merged with higher numbers taking precedence                       │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 5. Version and Release Management

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          VERSION MANAGEMENT FLOW                               │
│                                                                                 │
│  versions/applicationSets.yaml defines available releases:                      │
│                                                                                 │
│  releases:                                                                      │
│    addons:                                                                      │
│    - type: "default"     ← Default version for addons                          │
│      version: 0.3.1                                                            │
│    - type: "release1"    ← Named release for specific clusters                 │
│      version: 0.3.1                                                            │
│    monitoring:                                                                  │
│    - type: "default"     ← Default version for monitoring                      │
│      version: 0.1.0                                                            │
│                                                                                 │
│  Cluster labels control which version is deployed:                             │
│                                                                                 │
│  externalSecret:                                                                │
│    labels:                                                                      │
│      addonsRelease: release1      ← Uses "release1" version of addons          │
│      monitoringRelease: default   ← Uses "default" version of monitoring       │
│      enable_metrics_server: "true" ← Enables specific components               │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Key Concepts Summary

1. **ApplicationSet Wrapper Pattern**: The application-sets chart serves as a dynamic template generator
2. **Hierarchical Configuration**: Values cascade from system → tenant → environment → cluster
3. **Label-Based Selection**: Cluster labels determine what gets deployed and which version
4. **Dual Deployment Models**: Centralized (hub manages all) vs Distributed (spokes self-manage)
5. **Version Management**: Centralized version control with selective deployment capability
6. **Secure Registration**: AWS Secrets Manager + External Secrets for secure cluster onboarding
