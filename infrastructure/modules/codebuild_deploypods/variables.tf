# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

# CodeBuild ---------------------------------------------------------------------------
variable "deploypods_codebuild_project_name" {
  description = "Name of the CodeBuild project that restarts the app's pods on EKS so they pull the newest image"
  type        = string
}

variable "deploypods_codebuild_codeconnection_arn" {
  description = "ARN of the CodeConnections connection to GitHub that CodeBuild uses to clone the source"
  type        = string
  validation {
    condition     = can(regex("^arn:aws:code(star-)?connections:", var.deploypods_codebuild_codeconnection_arn))
    error_message = "deploypods_codebuild_codeconnection_arn must be a CodeConnections connection ARN."
  }
}

variable "deploypods_codebuild_eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "deploypods_codebuild_artifact_bucket_name" {
  description = "Name of the CodePipeline artifact bucket this project reads its source from when run as a pipeline stage"
  type        = string
}

variable "deploypods_codebuild_log_retention_days" {
  description = "Days CloudWatch keeps this project's build logs. 0 keeps them forever."
  type        = number
  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365], var.deploypods_codebuild_log_retention_days)
    error_message = "deploypods_codebuild_log_retention_days must be a retention value CloudWatch accepts."
  }
}

variable "deploypods_codebuild_source_location" {
  description = "HTTPS URL of the GitHub repository CodeBuild clones"
  type        = string
  validation {
    condition     = can(regex("^https://github\\.com/[^/]+/[^/]+$", var.deploypods_codebuild_source_location))
    error_message = "deploypods_codebuild_source_location must be https://github.com/<owner>/<repo> with no trailing path."
  }
}

variable "deploypods_codebuild_source_version" {
  description = "Branch, tag, or commit ID CodeBuild builds from"
  type        = string
}

variable "deploypods_codebuild_buildspec" {
  description = "Path to the buildspec file, relative to the repository root"
  type        = string
}

variable "deploypods_codebuild_image" {
  description = "Managed CodeBuild image the build container runs. Must ship the Python version the buildspec requests."
  type        = string
}

variable "deploypods_codebuild_compute_type" {
  description = "Build container size. Allowed: BUILD_GENERAL1_SMALL, BUILD_GENERAL1_MEDIUM, BUILD_GENERAL1_LARGE."
  type        = string
  validation {
    condition = contains(
      ["BUILD_GENERAL1_SMALL", "BUILD_GENERAL1_MEDIUM", "BUILD_GENERAL1_LARGE"],
      var.deploypods_codebuild_compute_type
    )
    error_message = "deploypods_codebuild_compute_type must be one of: BUILD_GENERAL1_SMALL, BUILD_GENERAL1_MEDIUM, BUILD_GENERAL1_LARGE."
  }
}

variable "deploypods_codebuild_build_timeout" {
  description = "Minutes before CodeBuild aborts a running build"
  type        = number
  validation {
    condition     = var.deploypods_codebuild_build_timeout >= 5 && var.deploypods_codebuild_build_timeout <= 480
    error_message = "deploypods_codebuild_build_timeout must be between 5 and 480 minutes."
  }
}