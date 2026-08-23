# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

# CodeBuild ---------------------------------------------------------------------------
variable "unittest_codebuild_project_name" {
  description = "Name of the CodeBuild project that lints and unit-tests the Django app"
  type        = string
}

variable "unittest_codebuild_service_role_arn" {
  description = "ARN of the IAM service role CodeBuild assumes to write logs and publish reports"
  type        = string
  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/", var.unittest_codebuild_service_role_arn))
    error_message = "unittest_codebuild_service_role_arn must be a valid IAM role ARN."
  }
}

variable "unittest_codebuild_source_location" {
  description = "HTTPS URL of the GitHub repository CodeBuild clones"
  type        = string
  validation {
    condition     = can(regex("^https://github\\.com/[^/]+/[^/]+$", var.unittest_codebuild_source_location))
    error_message = "unittest_codebuild_source_location must be https://github.com/<owner>/<repo> with no trailing path."
  }
}

variable "unittest_codebuild_source_version" {
  description = "Branch, tag, or commit ID CodeBuild builds from"
  type        = string
}

variable "unittest_codebuild_buildspec" {
  description = "Path to the buildspec file, relative to the repository root"
  type        = string
}

variable "unittest_codebuild_image" {
  description = "Managed CodeBuild image the build container runs. Must ship the Python version the buildspec requests."
  type        = string
}

variable "unittest_codebuild_compute_type" {
  description = "Build container size. Allowed: BUILD_GENERAL1_SMALL, BUILD_GENERAL1_MEDIUM, BUILD_GENERAL1_LARGE."
  type        = string
  validation {
    condition = contains(
      ["BUILD_GENERAL1_SMALL", "BUILD_GENERAL1_MEDIUM", "BUILD_GENERAL1_LARGE"],
      var.unittest_codebuild_compute_type
    )
    error_message = "unittest_codebuild_compute_type must be one of: BUILD_GENERAL1_SMALL, BUILD_GENERAL1_MEDIUM, BUILD_GENERAL1_LARGE."
  }
}

variable "unittest_codebuild_build_timeout" {
  description = "Minutes before CodeBuild aborts a running build"
  type        = number
  validation {
    condition     = var.unittest_codebuild_build_timeout >= 5 && var.unittest_codebuild_build_timeout <= 480
    error_message = "unittest_codebuild_build_timeout must be between 5 and 480 minutes."
  }
}