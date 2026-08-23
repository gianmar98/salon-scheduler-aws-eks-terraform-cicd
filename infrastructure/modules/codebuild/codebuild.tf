# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

resource "aws_codebuild_project" "unittest" {
  name           = var.unittest_codebuild_project_name
  service_role   = aws_iam_role.unittest.arn
  build_timeout  = var.unittest_codebuild_build_timeout #mins before build is aborted
  source_version = var.unittest_codebuild_source_version #"main" or branch chosen

  artifacts { #output files, compiled code, test results, deployable packages
    type = "NO_ARTIFACTS"
  }

  cache {
    type = "NO_CACHE"
  }

  environment {
    type                        = "LINUX_CONTAINER"
    compute_type                = var.unittest_codebuild_compute_type
    image                       = var.unittest_codebuild_image
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = false
  }

  logs_config {
    cloudwatch_logs {
      status     = "ENABLED"
      group_name = aws_cloudwatch_log_group.unittest.name
    }

    s3_logs {
      status = "DISABLED"
    }
  }

  source {
    type            = "GITHUB"
    location        = var.unittest_codebuild_source_location
    buildspec       = var.unittest_codebuild_buildspec
    git_clone_depth = 1
  }
}