# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

# Stable in-cluster address for the pods. The Ingress points here, and the ALB sends
# traffic through it. Was type LoadBalancer (a Classic LB) until Lab 9 swapped in the ALB.
resource "kubernetes_service_v1" "appointments" {
  # Its own flag, separate from eks_enabled, because the kubernetes provider reads the
  # cluster address from this module. Removing the module takes that address with it, and
  # Terraform then has nowhere to send the delete — it fails against localhost. Shutting
  # down is two applies: eks_app_enabled = false first, then eks_enabled = false.
  count = var.eks_app_enabled ? 1 : 0

  metadata {                             #object's identifier in the cluster
    name      = var.eks_app_service_name #deployment's name in cluster
    namespace = var.eks_app_namespace    #folder it lives in (default)

    labels = {
      app = var.eks_app_selector #tags on service itself
    }
  }

  spec {
    # The only link to the Deployment."send traffic to every pod labeled like this"
    #Pods are found by label, never by name and keeps working like that as pods get replaced
    selector = {
      #Service choosing which pods to send traffic to
      app = var.eks_app_selector
    }

    port {
      port        = 80                         # the load balancer fronts a web app
      target_port = var.eks_app_container_port #port inside container (8088) so browser -> 80 on LB -> 8088 in a pod
      protocol    = "TCP"
    }

    type = "ClusterIP" #inside the cluster only; the ALB is the front door
  }
}