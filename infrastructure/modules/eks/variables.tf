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

variable "eks_kubernetes_version" {
  description = "Kubernetes minor version of the control plane — pin it or AWS picks the current default"
  type        = string
}

# NODE GROUP ---------------------------------------------------------------------
variable "eks_node_group_name" {
  description = "Node group name — env-suffixed by the caller"
  type        = string
}

variable "eks_node_capacity_type" {
  description = "SPOT for reclaimable spare capacity, ON_DEMAND for guaranteed"
  type        = string

  validation {
    condition     = contains(["SPOT", "ON_DEMAND"], var.eks_node_capacity_type)
    error_message = "Capacity type must be SPOT or ON_DEMAND"
  }
}

variable "eks_node_instance_types" {
  description = "Instance types the node group may launch — must all match ami_type's architecture"
  type        = list(string)

  validation {
    condition     = length(var.eks_node_instance_types) >= 1
    error_message = "At least one instance type is required"
  }
}

variable "eks_node_disk_size" {
  description = "EBS volume size per node, in GiB"
  type        = number
}

variable "eks_node_desired_size" {
  description = "Nodes to run now — must sit between min and max"
  type        = number
}

variable "eks_node_min_size" {
  description = "Lower bound on node count"
  type        = number
}

variable "eks_node_max_size" {
  description = "Upper bound on node count"
  type        = number
}

# EKS AGENT ----------------------------------
variable "eks_app_namespace" {
  description = "Namespace the app pods run in"
  type        = string
}

variable "eks_app_service_account" {
  description = "Service account the app pods run as — must match serviceAccountName in the deployment manifest"
  type        = string
}

