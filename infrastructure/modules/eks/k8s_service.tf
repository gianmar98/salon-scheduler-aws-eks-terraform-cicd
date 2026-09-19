# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

# The one Kubernetes object Terraform owns rather than kubectl.
#
# `type = LoadBalancer` makes Kubernetes ask AWS for a classic load balancer — a real,
# billable AWS resource that Terraform did not create and therefore would not destroy.
# Applied with kubectl, it outlives `eks_enabled = false` as an orphan with no owner.
# Declared here it is in state, so destroying the cluster deletes the Service first and
# Kubernetes releases the load balancer on the way out.
#
# The Deployment and ServiceAccount stay in appointments-app/manifests/ on purpose: they
# create nothing outside the cluster, so they cannot be orphaned.
resource "kubernetes_service_v1" "appointments" {
  # Its own flag, separate from eks_enabled, because the kubernetes provider reads the
  # cluster address from this module. Removing the module takes that address with it, and
  # Terraform then has nowhere to send the delete — it fails against localhost. Shutting
  # down is two applies: eks_app_enabled = false first, then eks_enabled = false.
  count = var.eks_app_enabled ? 1 : 0

  metadata { #object's identifier in the cluster
    name      = var.eks_app_service_name
    namespace = var.eks_app_namespace #folder it lives in (default)

    labels = {
      app = var.eks_app_selector #tags on service itself
    }
  }

  spec {
    # The only link to the Deployment.
    # "send traffic to very pod labeled like this"
    #Pods are found by label, never by name and keeps working like that as pods get replaced
    selector = {
      app = var.eks_app_selector
    }

    port {
      port        = 80 # the load balancer fronts a web app
      target_port = var.eks_app_container_port #port inside container (8088) so browser -> 80 on LB -> 8088 in a pod
      protocol    = "TCP"
    }

    type = "LoadBalancer" #Go get a LB
  }

  # Blocks until the load balancer reports an endpoint, so `app_url` is never empty.
  wait_for_load_balancer = true
}