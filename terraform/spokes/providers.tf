provider "helm" {
  kubernetes {
    host                   = local.cluster_info.cluster_endpoint
    cluster_ca_certificate = base64decode(local.cluster_info.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = [
        "eks",
        "get-token",
        "--cluster-name", local.cluster_info.cluster_name,
        "--region", local.region
      ]
    }
  }
}

provider "kubernetes" {
  host                   = local.cluster_info.cluster_endpoint
  cluster_ca_certificate = base64decode(local.cluster_info.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = [
      "eks",
      "get-token",
      "--cluster-name", local.cluster_info.cluster_name,
      "--region", local.region
    ]
  }
}

provider "aws" {
  region = "eu-west-2"
}

provider "aws" {
  alias  = "shared-services"
  region = "eu-west-2"
  assume_role {
    role_arn     = "arn:aws:iam::${var.hub_account_id}:role/cross-account-role"
    session_name = "shared-services"
    external_id  = "eks-fleet-management"
  }
}

terraform {
  backend "s3" {
  }
}
