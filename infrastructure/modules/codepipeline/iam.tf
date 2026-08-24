# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

locals {
  # AWS renamed codestar-connections to codeconnections and honors both.
  codeconnection_arns = [
    replace(var.application_pipeline_codeconnection_arn, ":codestar-connections:", ":codeconnections:"),
    replace(var.application_pipeline_codeconnection_arn, ":codeconnections:", ":codestar-connections:"),
  ]
}

data "aws_iam_policy_document" "application_pipeline_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

#Role that can be assumed by code pipeline
resource "aws_iam_role" "application_pipeline_role" {
  name               = "${var.application_pipeline_name}-service-role"
  assume_role_policy = data.aws_iam_policy_document.application_pipeline_assume_role.json
}

data "aws_iam_policy_document" "application_pipeline" {
  # Source writes the repo zip here, Build reads it back.
  statement {
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObject",
    ]
    resources = [
      module.artifacts_s3_bucket.s3_bucket_arn,
      "${module.artifacts_s3_bucket.s3_bucket_arn}/*",
    ]
  }

  # Clone the repo through the GitHub connection the env layer owns.
  #UseConnection lets the source stage borrow GitHub credentials to clone repo so pipeline can fetch it (honoring both codestar and codeconnections)
  statement {
    actions   = ["codestar-connections:UseConnection", "codeconnections:UseConnection"]
    resources = local.codeconnection_arns
  }

  # Lets Build stage kick off your CodeBuild project and poll it for result. Scoped to projects ARN
  statement {
    actions   = ["codebuild:StartBuild", "codebuild:BatchGetBuilds"]
    resources = [var.application_pipeline_codebuild_project_arn]
  }
}

resource "aws_iam_role_policy" "application_pipeline" {
  name   = "${var.application_pipeline_name}-service-role-policy"
  role   = aws_iam_role.application_pipeline_role.id
  policy = data.aws_iam_policy_document.application_pipeline.json
}
