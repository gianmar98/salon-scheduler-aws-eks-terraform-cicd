# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

#POD IDENTITY AGENT (temp IAM creds to access services) ---------------------------------------
#install aws credentials-delivery agent onto nodes and gives credentials to nodes when pod asks them
resource "aws_eks_addon" "pod_identity_agent" {
  addon_name   = "eks-pod-identity-agent"
  cluster_name = aws_eks_cluster.salon_eks_cluster.name

  #Pod agent has to be created after the node exists, if not it cannot run
  depends_on = [aws_eks_node_group.salon_eks_node]
}

# APP ROLE ----------------------------------------------------
# Trust Policy: who can take the role (EKS pods service)
data "aws_iam_policy_document" "eks_app_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    #TagSession is needed since Pod Identity labels the session with the namespace and service account name. it cannot assume without it
    actions = ["sts:AssumeRole", "sts:TagSession"]

  }
}

resource "aws_iam_role" "eks_app_role" {
  name               = "${var.eks_cluster_name}-app-role"
  assume_role_policy = data.aws_iam_policy_document.eks_app_assume_role.json
}

# Map Kubernetes service account to the IAM role above
# "any pod in service account "appointments-sa" in namespace "default" gets this role"
resource "aws_eks_pod_identity_association" "appointments_app" {
  role_arn        = aws_iam_role.eks_app_role.arn
  cluster_name    = aws_eks_cluster.salon_eks_cluster.name
  namespace       = var.eks_app_namespace #folder inside cluster (Secured office building/logical boundary/container)
  service_account = var.eks_app_service_account #employee ID badge (account to give apps permissions to do things)
}
