# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

#Pod's identity. Maps this name to app IAM role and admission controller rejects every pod unit it exists
resource "kubernetes_service_account_v1" "appointments" {
  count = var.eks_app_enabled ? 1: 0

  metadata {
    name = var.eks_app_service_account #name aws_eks_pod_identity_association points at
    namespace = var.eks_app_namespace
  }
}