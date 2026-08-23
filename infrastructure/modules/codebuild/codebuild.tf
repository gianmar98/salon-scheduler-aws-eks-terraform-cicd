# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

resource "aws_codebuild_project" "unittest" {
  name           = var.unittest_codebuild_project_name
  service_role   = var.unittest_codebuild_service_role_arn
  build_timeout  = var.unittest_codebuild_build_timeout
  source_version = var.unittest_codebuild_source_version

  artifacts {
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
      status = "ENABLED"
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