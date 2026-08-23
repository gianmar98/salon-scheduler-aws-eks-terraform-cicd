# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

# Names and paths match what the console generated, so these could be imported instead
# of replaced. Still built from the project name, so the module stays reusable.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  service_role_path = "/service-role/"

  # The log group ARN ends in ":*"; the statement needs it both ways.
  log_group_arn = trimsuffix(aws_cloudwatch_log_group.unittest.arn, ":*")

  # AWS renamed codestar-connections to codeconnections and honors both.
  codeconnection_arns = [
    replace(var.unittest_codebuild_codeconnection_arn, ":codestar-connections:", ":codeconnections:"),
    replace(var.unittest_codebuild_codeconnection_arn, ":codeconnections:", ":codestar-connections:"),
  ]
}

# Role -------------------------------------------------------------------------------
data "aws_iam_policy_document" "unittest_assume_role" { #Role assumable by codebuild
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "unittest" { #Role being allowed to be assumed by codebuild^^^
  name               = "codebuild-${var.unittest_codebuild_project_name}-service-role"
  path               = local.service_role_path
  assume_role_policy = data.aws_iam_policy_document.unittest_assume_role.json
}

# Base policy: logs, artifact buckets, reports --------------------------------------
data "aws_iam_policy_document" "unittest_base" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [local.log_group_arn, "${local.log_group_arn}:*"]
  }

  # Unused until this becomes a CodePipeline stage but part of console resource
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketAcl",
      "s3:GetBucketLocation",
    ]
    resources = ["arn:aws:s3:::codepipeline-${data.aws_region.current.region}-*"]
  }

  statement {
    actions = [
      "codebuild:CreateReportGroup",
      "codebuild:CreateReport",
      "codebuild:UpdateReport",
      "codebuild:BatchPutTestCases",
      "codebuild:BatchPutCodeCoverages",
    ]
    resources = [
      "arn:aws:codebuild:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:report-group/${var.unittest_codebuild_project_name}-*",
    ]
  }
}

resource "aws_iam_policy" "unittest_base" { #rednering JSON policy_document so this manages the policy object
  name        = "CodeBuildBasePolicy-${var.unittest_codebuild_project_name}-${data.aws_region.current.region}"
  path        = local.service_role_path
  description = "Policy used in trust relationship with CodeBuild"
  policy      = data.aws_iam_policy_document.unittest_base.json
}

resource "aws_iam_role_policy_attachment" "unittest_base" {
  role       = aws_iam_role.unittest.name
  policy_arn = aws_iam_policy.unittest_base.arn
}

# Source credentials policy: clone GitHub through CodeConnections ---------------------
data "aws_iam_policy_document" "unittest_codeconnections" {
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

resource "aws_iam_policy" "unittest_codeconnections" {
  name        = "CodeBuildCodeConnectionsSourceCredentialsPolicy-${var.unittest_codebuild_project_name}-${data.aws_region.current.region}-${data.aws_caller_identity.current.account_id}"
  path        = local.service_role_path
  description = "Policy used in trust relationship with CodeBuild"
  policy      = data.aws_iam_policy_document.unittest_codeconnections.json
}

resource "aws_iam_role_policy_attachment" "unittest_codeconnections" { #attaching policy to codebuild role
  role       = aws_iam_role.unittest.name
  policy_arn = aws_iam_policy.unittest_codeconnections.arn
}
