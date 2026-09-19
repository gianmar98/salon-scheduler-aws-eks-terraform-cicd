# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0


# Deployment has its values (image URI, DB endpoint) are outputs of this same run
resource "kubernetes_deployment_v1" "appointments" {
  count = var.eks_app_enabled ? 1 : 0 #same gate as Service

  metadata { #deployment's ID
    name      = var.eks_app_selector
    namespace = var.eks_app_namespace #same folder as service (default)

    labels = {
      app = var.eks_app_selector #Tag on deployment itself
    }
  }

  spec {
    replicas = var.eks_app_replicas #how many pods to keep alive. Kubernetes replaces any that terminate

    selector {
      match_labels = {             #how deployment recognizes pods it owns
        app = var.eks_app_selector #immutable after creation, changing it forces replacement
      }
    }

    template {
      metadata {
        labels = {
          app = var.eks_app_selector #stamps label on each pod and this is how the Service finds it
        }
      }

      spec {                                               #what is inside each pod
        service_account_name = var.eks_app_service_account #runs pods as appointments-sa, Pod Identity maps it to the IAM Role

        container {
          name              = "webserver"                                         #container name inside pod, what 'kubectl logs- -c' takes
          image             = "${var.eks_app_image_uri}:${var.eks_app_image_tag}" #repo URL form ECR module + tag from tfvars
          image_pull_policy = "Always"                                            #re pull every start because 'latest' can point at a new image
          port {
            container_port = var.eks_app_container_port #8088, Service's target_port is what routes here
          }
          env {
            name  = "AWS_DEFAULT_REGION"
            value = var.eks_app_aws_region #which region boto3 calls for DynamoDB
          }
          env {
            name  = "DATABASE_HOST"
            value = var.eks_app_db_host #RDS endpoint, wired from the rds module so a DB rebuild needs no hand edit
          }
          env {
            name  = "DATABASE_USER"
            value = var.eks_app_db_user #the IAM-authenticated MySQL user created in modules/rds
          }
          env {
            name  = "DATABASE_DB_NAME"
            value = var.eks_app_db_name #which database inside the instance
          }

          # IAM auth sends the token where a password normally goes. The MySQL client
          # refuses to transmit that in cleartext unless this is set — safe because the
          # connection is TLS-wrapped. Not a dial: IAM auth does not work without it.
          env {
            name  = "LIBMYSQL_ENABLE_CLEARTEXT_PLUGIN"
            value = "1"
          }
        }
      }
    }


  }



}
