# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

data "http" "myip" {
  url = "https://checkip.amazonaws.com"
}

resource "aws_eks_cluster" "salon_eks_cluster" {
  name     = var.eks_cluster_name
  role_arn = aws_iam_role.salon_eks_cluster_role.arn
  version  = var.eks_kubernetes_version

  vpc_config {
    subnet_ids          = var.eks_subnets_ids
    public_access_cidrs = ["${chomp(data.http.myip.response_body)}/32"] #only my current IP to access for now. chomp strips the response's trailing newline

    # Required whenever public_access_cidrs is narrowed: nodes reach the API server
    # from inside the VPC, and their IPs aren't on the allowlist. Without this they
    # never join and the node group hangs until it times out.
    endpoint_private_access = true
  }

  access_config {
    authentication_mode = "API" #Who can run kubectl. API means permissions only come from IAM access entries

    #---(Forces replacement if changed later)--#
    bootstrap_cluster_creator_admin_permissions = true #full admin inside Kubernetes who runs TF apply
    #------------------------------------------#
  }
  depends_on = [aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy] #build role first so there is no permission issues
}

resource "aws_eks_node_group" "salon_eks_node" {
  cluster_name = aws_eks_cluster.salon_eks_cluster.name

  node_group_name = var.eks_node_group_name
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = var.eks_subnets_ids

  capacity_type  = var.eks_node_capacity_type
  instance_types = var.eks_node_instance_types
  disk_size      = var.eks_node_disk_size
  ami_type       = "AL2023_x86_64_STANDARD" #EKS optimized AMI. T3 is x86 — not a tfvars dial, it must track the instance family

  scaling_config {
    desired_size = var.eks_node_desired_size
    min_size     = var.eks_node_min_size
    max_size     = var.eks_node_max_size
  }

  depends_on = [aws_iam_role_policy_attachment.eks_node_role_policy]
}

# Tags the ASG the node group creates, so launched instances get a Name in the EC2 console
resource "aws_autoscaling_group_tag" "node_name" {
  autoscaling_group_name = aws_eks_node_group.salon_eks_node.resources[0].autoscaling_groups[0].name

  tag {
    key                 = "Name"
    value               = "${var.eks_node_group_name}-node"
    propagate_at_launch = true
  }
}



