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

# Both of these feed the kubernetes provider in the env layer. They change on every rebuild.
output "cluster_endpoint" {
  description = "Kubernetes API server address — the kubernetes provider's host"
  value       = aws_eks_cluster.salon_eks_cluster.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 CA cert the kubernetes provider verifies the API server against"
  value       = aws_eks_cluster.salon_eks_cluster.certificate_authority[0].data
}

output "app_url" {
  description = "Public hostname of the load balancer the Service provisions — open with http, not https"
  value       = try("http://${kubernetes_service_v1.appointments[0].status[0].load_balancer[0].ingress[0].hostname}", null)
}
