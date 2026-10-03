# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

resource "aws_codebuild_project" "deploypods" {
  name           = var.deploypods_codebuild_project_name
  service_role   = aws_iam_role.deploypods.arn
  build_timeout  = var.deploypods_codebuild_build_timeout  #mins before build is aborted
  source_version = var.deploypods_codebuild_source_version #"main" or branch chosen

  artifacts { #output files, compiled code, test results, deployable packages
    type = "NO_ARTIFACTS"
  }

  cache {
    type = "NO_CACHE"
  }

  environment {
    type                        = "LINUX_CONTAINER"
    compute_type                = var.deploypods_codebuild_compute_type
    image                       = var.deploypods_codebuild_image
    image_pull_credentials_type = "CODEBUILD"

    # This project does not build images
    # privileged_mode = true

    # Read by buildspec_deploypods.yml for update-kubeconfig. Passed in so the "-dev"
    # suffix stays derived instead of hardcoded in the buildspec.
    environment_variable {
      name  = "EKS_CLUSTER_NAME"
      value = var.deploypods_codebuild_eks_cluster_name
    }
  }

  logs_config {
    cloudwatch_logs {
      status     = "ENABLED"
      group_name = aws_cloudwatch_log_group.deploypods.name
    }

    s3_logs {
      status = "DISABLED"
    }
  }

  source {
    type            = "GITHUB"
    location        = var.deploypods_codebuild_source_location
    buildspec       = var.deploypods_codebuild_buildspec
    git_clone_depth = 1
  }
}