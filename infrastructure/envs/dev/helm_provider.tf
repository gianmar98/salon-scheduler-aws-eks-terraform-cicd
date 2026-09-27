# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

#Tells helm how to log into cluster
provider "helm" {
  kubernetes = {
    #how to reach cluster
    host                   = try(module.eks[0].cluster_endpoint, "") #cluster's address; "" when eks_enabled=false
    cluster_ca_certificate = try(base64decode(module.eks[0].cluster_certificate_authority_data), "")
    #cluster's certificate so we know we are talking to the real cluster
    exec = {
      api_version = "client.authentication.k8s.io/v1" #get fresh login token
      command     = "aws"                             #binary to run. aws cli
      #Command to do, prints JSON with short-lived bearer token (STS) so EKS can verify it and learn IAM identity
      args = ["eks", "get-token", "--cluster-name", "${var.eks_cluster_name}${local.env_suffix}"]
    }
  }
}