# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

# Connection details for the cluster's own API, so Terraform can manage objects inside it.
# Same shape as mysql_provider.tf: the provider is configured here because it depends on a
# resource this layer builds, while the resources it manages live in the module.
#
# `try(..., "")` is required — with eks_enabled = false there is no module.eks[0]. Provider
# configuration is always evaluated, even when nothing uses it, so a bare reference errors.
# The empty values are harmless: with the module gone there are no kubernetes resources to
# act on.
provider "kubernetes" { #Writes into ~/.kube/config
  host                   = try(module.eks[0].cluster_endpoint, "")
  #Where to send requests, that is the cluster's IP address from EKS modul
  cluster_ca_certificate = try(base64decode(module.eks[0].cluster_certificate_authority_data), "")

  # No static token. The AWS CLI mints a short-lived one per operation, exactly as
  # `aws eks update-kubeconfig` sets kubectl up to do. A token from the
  # aws_eks_cluster_auth data source would be written to state instead.
  exec {
    api_version = "client.authentication.k8s.io/v1" #contract between kubernetes provider and aws
    command     = "aws" #binary to run
    #Command to do, prints JSON with short-lived bearer token (STS) so EKS can verify it and learn IAM identity
    args        = ["eks", "get-token", "--cluster-name", "${var.eks_cluster_name}${local.env_suffix}"]
  }
}