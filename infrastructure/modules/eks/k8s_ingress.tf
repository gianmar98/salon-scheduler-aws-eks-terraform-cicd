# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

#Work the controller acts on: "give internet facing ALB that sends to this service"
resource "kubernetes_ingress_v1" "appointments" {
  count = var.eks_app_enabled ? 1 : 0 #Gets removed before cluster does

  metadata {
    name      = var.eks_app_ingress_name
    namespace = var.eks_app_namespace

    annotations = {                                               #knobs ALB controller reads
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing" #public ALB; "internal" would be VPC-only
      "alb.ingress.kubernetes.io/target-type" = "ip"              #register pod IPs directly instead of ports
    }
  }

  spec {
    ingress_class_name = "alb" #matches IngressClass chart created. Claims object for controller

    rule {
      http {
        path {
          path      = "/" #everything / For this path send this to backend
          path_type = "Prefix"

          backend {
            service {                         #which is this service on this port 80
              name = var.eks_app_service_name # ClusterIP Service
              port {
                number = 80 #Service's port, forwards to 8088 in the container
              }
            }
          }
        }
      }
    }
  }
  wait_for_load_balancer = true
  depends_on             = [helm_release.alb_controller] #controller should be created first and deleted last
}
