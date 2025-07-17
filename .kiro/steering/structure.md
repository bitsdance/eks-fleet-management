# Project Structure & Organization

## Directory Structure Overview

```
/
├── addons/                  # Addon configurations and overrides
│   ├── bootstrap/           # Bootstrap-specific configurations
│   ├── control-plane/       # Control plane specific configurations
│   ├── defaults/            # Default configurations for all clusters
│   ├── hub/                 # Hub-specific configurations
│   └── tenants/             # Tenant-specific configurations
│       ├── defaults/        # Default tenant configurations
│       └── tenant1/         # Specific tenant configurations
├── charts/                  # Helm charts
│   ├── application-sets/    # Core ApplicationSet wrapper chart
│   ├── fleet-secret/        # Fleet secret management chart
│   └── [other charts]/      # Component-specific charts
├── fleet/                   # Fleet management configurations
│   ├── bootstrap/           # Hub cluster ApplicationSets
│   │   └── versions/        # Version management
│   └── fleet-bootstrap/     # Spoke cluster registration
│       ├── fleet-members/   # Spoke cluster configurations
│       └── members-application-sets/ # ApplicationSets for distributed model
├── resources/               # Resource configurations
└── terraform/               # Infrastructure as Code
    ├── hub/                 # Hub cluster Terraform
    └── spokes/              # Spoke cluster Terraform
```

## Configuration Hierarchy

The system uses a 5-level configuration hierarchy (from highest to lowest priority):

1. **Cluster-Specific**: `addons/tenants/{tenant}/clusters/{cluster-name}/{component}/`
2. **Environment-Specific**: `addons/tenants/{tenant}/environments/{environment}/{component}/`
3. **Tenant-Specific**: `addons/tenants/{tenant}/defaults/{component}/`
4. **Global Tenant Defaults**: `addons/tenants/defaults/{component}/`
5. **System-Wide Defaults**: `addons/defaults/{component}/`

## Key Files

### Fleet Bootstrap
- `fleet/bootstrap/addons.yaml`: Manages add-on deployment across the fleet
- `fleet/bootstrap/resources.yaml`: Handles fleet-wide resource deployments
- `fleet/bootstrap/fleetv2.yaml`: Manages spoke cluster registration process
- `fleet/bootstrap/versions/applicationSets.yaml`: Version control for components

### Fleet Registration
- `fleet/fleet-bootstrap/fleet-hub-external-secrets.yaml`: Main registration ApplicationSet
- `fleet/fleet-bootstrap/fleet-members/{hub}/{spoke}.yaml`: Spoke cluster configurations

### Configuration Files
- `addons/tenants/{tenant}/defaults/fleet/fleet-secret/values.yaml`: Cluster labels definition
- `charts/application-sets/templates/application-set.yaml`: Core template for ApplicationSets

## Naming Conventions

1. **Cluster Names**: `{environment}-{purpose}-{index}` (e.g., `dev-workload1`)
2. **ApplicationSets**: `{component}-{release}` (e.g., `cluster-addons-default`)
3. **Applications**: `{release}-{cluster}-{component}-{version}` (e.g., `default-spoke-np-metrics-server-1.0.0`)
4. **Configuration Files**: Follow the hierarchy path structure

## Code Organization Patterns

1. **Wrapper Pattern**: Application-sets chart wraps and generates multiple ApplicationSets
2. **Hierarchical Configuration**: Layered approach to configuration management
3. **Label-Based Selection**: Components deployed based on cluster labels
4. **Version Control**: Centralized version management with selective deployment
5. **Infrastructure/GitOps Separation**: Terraform for initial provisioning, GitOps for ongoing management