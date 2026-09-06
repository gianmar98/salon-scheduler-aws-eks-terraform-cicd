# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

resource "aws_eks_cluster" "salon_eks_cluster" {
  name     = var.eks_cluster_name
  role_arn = aws_iam_role.salon_eks_cluster_role.arn

  vpc_config {
    subnet_ids = var.eks_subnets_ids
  }
}

resource "aws_eks_node_group" "salon_eks_node" {
  cluster_name  = aws_eks_cluster.salon_eks_cluster.name
  node_role_arn = ""
  subnet_ids    = var.eks_subnets_ids
}


