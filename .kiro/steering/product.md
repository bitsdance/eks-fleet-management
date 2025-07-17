# GitOps Fleet Management System

## Product Overview
The GitOps Fleet Management system is a comprehensive solution for managing multiple Kubernetes clusters using ArgoCD. It provides a flexible approach to cluster management with support for both centralized and distributed (agent) deployment models.

## Key Features
- **Multi-cluster management** with hub-and-spoke architecture
- **Flexible deployment models**: centralized or distributed (agent-based)
- **Hierarchical configuration** with tenant/environment/cluster overrides
- **Dynamic ApplicationSet generation** using wrapper pattern
- **Secure cluster registration** via AWS Secrets Manager
- **Version management** with selective deployment
- **Label-based component selection**

## Core Components
1. **Fleet Bootstrap**: Initializes the hub cluster with core ApplicationSets
2. **Fleet Registration**: Handles registration and initialization of spoke clusters
3. **Application Sets Chart**: Wrapper/template generator for creating multiple ArgoCD ApplicationSets
4. **Configuration Hierarchy**: Layered configuration system for overrides
5. **Version Management**: Controls component versions across the fleet

## Deployment Models
- **Centralized Management**: Hub cluster's ArgoCD instance manages all resources on spoke clusters (`use_remote_argo: "false"`)
- **Distributed ("Agent") Model**: Hub deploys ArgoCD to spoke clusters, which then manage their own resources (`use_remote_argo: "true"`)