# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

# EKS ---------------------------------------------------------------------------
variable "eks_cluster_name" {
  description = "Cluster name — env-suffixed by the caller"
  type        = string
}

variable "eks_subnets_ids" {
  description = "Subnets the control plane and nodes run in - at least 2 AZs"
  type        = list(string)

  validation {
    condition     = length(var.eks_subnets_ids) >= 2
    error_message = "EKS needs subnets in at least 2 AZs"
  }
}

