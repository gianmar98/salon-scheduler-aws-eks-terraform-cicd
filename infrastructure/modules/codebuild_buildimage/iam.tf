# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

# Written directly in Terraform — unlike codebuild_unittest, nothing here was built in
# the console first. Names follow the same pattern so the two roles read alike.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  service_role_path = "/service-role/"

  # The log group ARN ends in ":*"; the statement needs it both ways.
  log_group_arn = trimsuffix(aws_cloudwatch_log_group.buildimage.arn, ":*")

  # AWS renamed codestar-connections to codeconnections and honors both.
  codeconnection_arns = [
    replace(var.buildimage_codebuild_codeconnection_arn, ":codestar-connections:", ":codeconnections:"),
    replace(var.buildimage_codebuild_codeconnection_arn, ":codeconnections:", ":codestar-connections:"),
  ]
}

# Role -------------------------------------------------------------------------------
data "aws_iam_policy_document" "buildimage_assume_role" { #Role assumable by codebuild
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "buildimage" { #Role being allowed to be assumed by codebuild^^^
  name               = "codebuild-${var.buildimage_codebuild_project_name}-service-role"
  path               = local.service_role_path
  assume_role_policy = data.aws_iam_policy_document.buildimage_assume_role.json
}

# Base policy: logs, artifact buckets, reports --------------------------------------
data "aws_iam_policy_document" "buildimage_base" {
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
      "arn:aws:s3:::${var.buildimage_codebuild_artifact_bucket_name}",
      "arn:aws:s3:::${var.buildimage_codebuild_artifact_bucket_name}/*",
    ]
  }

  # `docker login`. ECR has no permanent password, so this generates a temporary one that
  # lasts 12 hours. It covers the whole registry, not one repo, so "*" is the only scope
  # AWS accepts here.
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # `docker push`, broken into the calls it actually makes. Locked to this one repository.
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability", # which layers does ECR already have?
      "ecr:InitiateLayerUpload",         # start a layer
      "ecr:UploadLayerPart",             # send the bytes
      "ecr:CompleteLayerUpload",         # finish it
      "ecr:PutImage",                    # write the manifest: what makes the tags real
    ]
    resources = [var.buildimage_codebuild_ecr_repository_arn]
  }
}

resource "aws_iam_policy" "buildimage_base" { #rednering JSON policy_document so this manages the policy object
  name        = "CodeBuildBasePolicy-${var.buildimage_codebuild_project_name}-${data.aws_region.current.region}"
  path        = local.service_role_path
  description = "Policy used in trust relationship with CodeBuild"
  policy      = data.aws_iam_policy_document.buildimage_base.json
}

resource "aws_iam_role_policy_attachment" "buildimage_base" {
  role       = aws_iam_role.buildimage.name
  policy_arn = aws_iam_policy.buildimage_base.arn
}

# Source credentials policy: clone GitHub through CodeConnections ---------------------
data "aws_iam_policy_document" "buildimage_codeconnections" {
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

resource "aws_iam_policy" "buildimage_codeconnections" {
  name        = "CodeBuildCodeConnectionsSourceCredentialsPolicy-${var.buildimage_codebuild_project_name}-${data.aws_region.current.region}-${data.aws_caller_identity.current.account_id}"
  path        = local.service_role_path
  description = "Policy used in trust relationship with CodeBuild"
  policy      = data.aws_iam_policy_document.buildimage_codeconnections.json
}

resource "aws_iam_role_policy_attachment" "buildimage_codeconnections" { #attaching policy to codebuild role
  role       = aws_iam_role.buildimage.name
  policy_arn = aws_iam_policy.buildimage_codeconnections.arn
}
