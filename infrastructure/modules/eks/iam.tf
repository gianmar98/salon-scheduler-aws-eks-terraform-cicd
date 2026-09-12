# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

# EKS ---------------------------------------------------------------------
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

# Create the IAM role that is assumable by EKS
resource "aws_iam_role" "salon_eks_cluster_role" {
  name               = "${var.eks_cluster_name}-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json #can be assumed by EKS
}

# Attach policy to EKS IAM Role
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.salon_eks_cluster_role.name
}

# EKS Node Group---------------------------------------------------------------------
# EKS Node (EC2) trust policy
data "aws_iam_policy_document" "eks_node_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

#Create Role that is assumable by node groups
resource "aws_iam_role" "eks_node_role" {
  name               = "${var.eks_cluster_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json
}


#Attach policy to node group IAM role
resource "aws_iam_role_policy_attachment" "eks_node_role_policy" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",         #instance bootstrap itself to the cluster. If not instance boots but never shows up in kubectl get nodes (register)
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",              #EKS gives each node a real VPC IP, so to call CNI (Create NI)/AttachNI/AssignPrivIP to handle those IPs. Node joins but without this fails to assign an IP address to the container
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly" #download image from ECR (if skipped you get ImagePullBackOff). connects cluster to pipeline
  ])

  policy_arn = each.value
  role       = aws_iam_role.eks_node_role.name
}
