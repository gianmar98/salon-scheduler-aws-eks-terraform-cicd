# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0


# Trust Policy for EKS Service
data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# Create the IAM Role
resource "aws_iam_role" "salon_eks_cluster_role" {
  name               = "${var.eks_cluster_name}-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json #can be assumed by EKS
}

# Attach policy
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.salon_eks_cluster_role.name
}