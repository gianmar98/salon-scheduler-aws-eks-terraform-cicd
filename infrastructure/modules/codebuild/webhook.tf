# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

# All three filters must match for a build to be triggered. The file-path filter is what keeps
# Terraform-only commits from triggering the Django tests.
resource "aws_codebuild_webhook" "unittest" {
  project_name = aws_codebuild_project.unittest.name
  build_type   = "BUILD"

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }

    filter {
      type    = "HEAD_REF"
      pattern = var.unittest_codebuild_webhook_branch_pattern #reference of main of my project
    }

    filter {
      type    = "FILE_PATH"
      pattern = var.unittest_codebuild_webhook_file_path_pattern #appointments-app (which is my django app)
    }
  }

  pull_request_build_policy {                       #protection against CodeBuild attach (anyone opens a pull request and branch's code runs inside AWS account with service role credentials)
    requires_comment_approval = "ALL_PULL_REQUESTS" #PR NEVER builds on its own, someone has to comment approval on the PR first (Already filtered by just "PUSH" inside my filter group type of event pattern)
    approver_roles            = ["GITHUB_WRITE", "GITHUB_MAINTAIN", "GITHUB_ADMIN"]
  }
}