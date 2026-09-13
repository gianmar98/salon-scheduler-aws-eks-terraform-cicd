# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

data "aws_region" "current" {}

output "kubeconfig_command" {
  description = "Run this after every rebuild. The endpoint and CA change each time"
  value       = "aws eks update-kubeconfig --region ${data.aws_region.current.region} --name ${aws_eks_cluster.salon_eks_cluster.name}"
}

output "cluster_security_group_id" {
  description = "SG EKS attaches to the control plane and managed nodes so RDS can allow as an inbound rule"
  value       = aws_eks_cluster.salon_eks_cluster.vpc_config[0].cluster_security_group_id #managed SG by EKS
}
