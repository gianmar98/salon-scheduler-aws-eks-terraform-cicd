# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

#Tagging the default subnets of AZs "use1-az1", "use1-az2", "use1-az6" from my data "aws_subnets"
#ALB controller running inside cluster has to decide which subnets to put it in so it lists every subnets
#     in the VPC and keeps the ones tagged kubernetes.io/role/elb

#"AUTO DISCOVER all subnets that have the tag 'kubernetes.io/role/elb'"

#Tag the AWS LB Controller's auto discovery looks for.
resource "aws_ec2_tag" "subnet_elb_role" {
  for_each = toset(var.eks_subnets_ids) #tagging subnets

  #You may put a public LB in this subnet
  resource_id = each.value
  key         = "kubernetes.io/role/elb" #This marks a subnet as valid home for an internet-facing LB
  value       = "1"
}

#claims subnet for this cluster.
resource "aws_ec2_tag" "subnet_cluster" {
  for_each = toset(var.eks_subnets_ids) #tagging subnets

  #Subnet belongs to this cluster
  resource_id = each.value
  key         = "kubernetes.io/cluster/${var.eks_cluster_name}" #says which cluster a subnet belongs to, so that clusters sharing a VPC don't each grab the other's subnmets
  value       = "shared"
}