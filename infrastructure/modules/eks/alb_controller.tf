# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

# AWS LB controller runs as a pod in the cluster and calls AWS API to
#   build the ALB an Ingress asks for. Own ServiceAccount and its own role

#Trust policy
data "aws_iam_policy_document" "alb_controller_assume_role" {
  statement {
    effect = "Allow"
    principals {
      identifiers = ["pods.eks.amazonaws.com"]
      type        = "Service"
    }
    actions = ["sts:AssumeRole", "sts:TagSession"] #Tag session since pod identity stamps the namespace and service account name onto the session tags so assume call works
  }
}

#Role
resource "aws_iam_role" "alb_controller_role" {
  name               = "${var.eks_cluster_name}-alb-controller-role"
  assume_role_policy = data.aws_iam_policy_document.alb_controller_assume_role.json
}

#Policy
resource "aws_iam_policy" "alb_controller_policy" {
  name   = "${var.eks_cluster_name}-alb-controller-policy"
  policy = file("${path.module}/alb_controller_iam_policy_v3.5.0.json")
}

#Attach policy to role
resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller_role.name
  policy_arn = aws_iam_policy.alb_controller_policy.arn
}

resource "aws_eks_pod_identity_association" "alb_controller_association" {
  cluster_name    = aws_eks_cluster.salon_eks_cluster.name
  namespace       = var.eks_alb_controller_namespace
  role_arn        = aws_iam_role.alb_controller_role.arn
  service_account = var.eks_alb_controller_service_account
}