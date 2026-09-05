# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

# Declared up front so retention is managed. CodeBuild would otherwise create this on the
# first build and keep the logs forever.
resource "aws_cloudwatch_log_group" "buildimage" {
  name              = "/aws/codebuild/${var.buildimage_codebuild_project_name}"
  retention_in_days = var.buildimage_codebuild_log_retention_days
}