# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

#access configuration for the EKS cluster
resource "aws_eks_access_entry" "eks_entry" {
  cluster_name  = aws_eks_cluster.salon_eks_cluster.name
  principal_arn = var.eks_deploy_role_arn
}

#What the pass allows
resource "aws_eks_access_policy_association" "eks_entry" {
  cluster_name  = aws_eks_cluster.salon_eks_cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy" #"Edit" means it can change the app, which is all a restart needs
  principal_arn = aws_eks_access_entry.eks_entry.principal_arn

  access_scope {
    type       = "namespace"
    namespaces = [var.eks_app_namespace] #limits pass to your app's folder (default)
  }
}
