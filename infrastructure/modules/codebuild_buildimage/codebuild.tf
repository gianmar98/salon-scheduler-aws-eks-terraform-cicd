# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

resource "aws_codebuild_project" "buildimage" {
  name           = var.buildimage_codebuild_project_name
  service_role   = aws_iam_role.buildimage.arn
  build_timeout  = var.buildimage_codebuild_build_timeout  #mins before build is aborted
  source_version = var.buildimage_codebuild_source_version #"main" or branch chosen

  artifacts { #output files, compiled code, test results, deployable packages
    type = "NO_ARTIFACTS"
  }

  cache {
    type = "NO_CACHE"
  }

  environment {
    type                        = "LINUX_CONTAINER"
    compute_type                = var.buildimage_codebuild_compute_type
    image                       = var.buildimage_codebuild_image
    image_pull_credentials_type = "CODEBUILD"

    # The build itself runs inside a container, and `docker build` needs to run Docker
    # inside that container. Normally that is blocked. This unblocks it.
    # Off = "Cannot connect to the Docker daemon". Not a dial: an image builder needs it.
    privileged_mode = true

    # Read by buildspec_buildimage.yml for the login, the tags, and the push. Passed in
    # so the "-dev" suffix stays derived instead of hardcoded in the buildspec.
    environment_variable {
      name  = "ECR_REPO_URL"
      value = var.buildimage_codebuild_ecr_repository_url
    }
  }

  logs_config {
    cloudwatch_logs {
      status     = "ENABLED"
      group_name = aws_cloudwatch_log_group.buildimage.name
    }

    s3_logs {
      status = "DISABLED"
    }
  }

  source {
    type            = "GITHUB"
    location        = var.buildimage_codebuild_source_location
    buildspec       = var.buildimage_codebuild_buildspec
    git_clone_depth = 1
  }
}