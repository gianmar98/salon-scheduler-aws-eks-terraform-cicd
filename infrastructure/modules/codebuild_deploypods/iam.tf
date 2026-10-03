# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

# Written directly in Terraform — unlike codebuild_unittest, nothing here was built in
# the console first. Names follow the same pattern so the two roles read alike.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  service_role_path = "/service-role/"

  # The log group ARN ends in ":*"; the statement needs it both ways.
  log_group_arn = trimsuffix(aws_cloudwatch_log_group.deploypods.arn, ":*")

  # AWS renamed codestar-connections to codeconnections and honors both.
  codeconnection_arns = [
    replace(var.deploypods_codebuild_codeconnection_arn, ":codestar-connections:", ":codeconnections:"),
    replace(var.deploypods_codebuild_codeconnection_arn, ":codeconnections:", ":codestar-connections:"),
  ]
}

# Role -------------------------------------------------------------------------------
data "aws_iam_policy_document" "deploypods_assume_role" { #Role assumable by codebuild
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "deploypods" { #Role being allowed to be assumed by codebuild^^^
  name               = "codebuild-${var.deploypods_codebuild_project_name}-service-role"
  path               = local.service_role_path
  assume_role_policy = data.aws_iam_policy_document.deploypods_assume_role.json
}

# Base policy: logs, artifact buckets, reports --------------------------------------
data "aws_iam_policy_document" "deploypods_base" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [local.log_group_arn, "${local.log_group_arn}:*"]
  }

  # Read by the pipeline's Build stage: the source zip arrives through this bucket.
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketAcl",
      "s3:GetBucketLocation",
    ]
    resources = [
      "arn:aws:s3:::${var.deploypods_codebuild_artifact_bucket_name}",
      "arn:aws:s3:::${var.deploypods_codebuild_artifact_bucket_name}/*",
    ]
  }

  statement {
    actions = [
      "eks:DescribeCluster" #so update-kubeconfig can look up the cluster's address. "What is this cluster's address?"
    ]
    resources = [ #look into cluster's ARN
      "arn:aws:eks:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:cluster/${var.deploypods_codebuild_eks_cluster_name}"
    ]
  }

  statement {
    actions = [ #list my load balancers. "Print site's address in build log after deploy so we can copy it and check it
      "elasticloadbalancing:DescribeLoadBalancers"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "deploypods_base" { #rednering JSON policy_document so this manages the policy object
  name        = "CodeBuildBasePolicy-${var.deploypods_codebuild_project_name}-${data.aws_region.current.region}"
  path        = local.service_role_path
  description = "Policy used in trust relationship with CodeBuild"
  policy      = data.aws_iam_policy_document.deploypods_base.json
}

resource "aws_iam_role_policy_attachment" "deploypods_base" {
  role       = aws_iam_role.deploypods.name
  policy_arn = aws_iam_policy.deploypods_base.arn
}

# Source credentials policy: clone GitHub through CodeConnections ---------------------
data "aws_iam_policy_document" "deploypods_codeconnections" {
  statement {
    actions = [
      "codestar-connections:GetConnectionToken",
      "codestar-connections:GetConnection",
      "codeconnections:GetConnectionToken",
      "codeconnections:GetConnection",
      "codeconnections:UseConnection",
    ]
    resources = local.codeconnection_arns
  }
}

resource "aws_iam_policy" "deploypods_codeconnections" {
  name        = "CodeBuildCodeConnectionsSourceCredentialsPolicy-${var.deploypods_codebuild_project_name}-${data.aws_region.current.region}-${data.aws_caller_identity.current.account_id}"
  path        = local.service_role_path
  description = "Policy used in trust relationship with CodeBuild"
  policy      = data.aws_iam_policy_document.deploypods_codeconnections.json
}

resource "aws_iam_role_policy_attachment" "deploypods_codeconnections" { #attaching policy to codebuild role
  role       = aws_iam_role.deploypods.name
  policy_arn = aws_iam_policy.deploypods_codeconnections.arn
}
