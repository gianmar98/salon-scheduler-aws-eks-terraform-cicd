# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

# CodeBuild creates this group on the first build. Imported here so retention is managed
resource "aws_cloudwatch_log_group" "unittest" {
  name              = "/aws/codebuild/${var.unittest_codebuild_project_name}"
  retention_in_days = var.unittest_codebuild_log_retention_days
}