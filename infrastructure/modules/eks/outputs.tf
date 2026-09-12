# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

data "aws_region" "current" {}

output "kubeconfig_command" {
  description = "Run this after every rebuild. The endpoint and CA change each time"
  value       = "aws eks update-kubeconfig --region ${data.aws_region.current.region} --name ${aws_eks_cluster.salon_eks_cluster.name}"
}