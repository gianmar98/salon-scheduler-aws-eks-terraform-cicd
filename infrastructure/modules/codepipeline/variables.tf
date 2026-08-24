# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

# CodePipeline -------------------------------------------------------------------------
variable "application_pipeline_name" {
  description = "Name of my CodePipeline"
  type        = string
}

variable "application_pipeline_execution_mode" {
  description = "How the pipeline handles concurrent executions. Allowed: QUEUED, SUPERSEDED, PARALLEL."
  type        = string
  validation {
    condition     = contains(["QUEUED", "SUPERSEDED", "PARALLEL"], var.application_pipeline_execution_mode)
    error_message = "application_pipeline_execution_mode must be one of: QUEUED, SUPERSEDED, PARALLEL."
  }
}

variable "application_pipeline_artifact_bucket_name" {
  description = "Name of the S3 bucket stages pass artifacts through. Globally unique."
  type        = string
}

variable "application_pipeline_artifact_retention_days" {
  description = "Days before pipeline artifacts are expired from the bucket"
  type        = number
  validation {
    condition     = var.application_pipeline_artifact_retention_days > 0
    error_message = "application_pipeline_artifact_retention_days must be greater than 0."
  }
}

variable "application_pipeline_codeconnection_arn" {
  description = "ARN of the CodeConnections connection to GitHub the Source stage clones through"
  type        = string
  validation {
    condition     = can(regex("^arn:aws:code(star-)?connections:", var.application_pipeline_codeconnection_arn))
    error_message = "application_pipeline_codeconnection_arn must be a CodeConnections connection ARN."
  }
}

variable "application_pipeline_full_repository_id" {
  description = "Repository the Source stage clones, as <owner>/<repo> — not a URL"
  type        = string
  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.application_pipeline_full_repository_id))
    error_message = "application_pipeline_full_repository_id must be <owner>/<repo>, with no scheme or trailing path."
  }
}

variable "application_pipeline_branch_name" {
  description = "Branch the Source stage watches and clones"
  type        = string
}

variable "application_pipeline_trigger_file_paths" {
  description = "Glob patterns a changed file must match for a push to start the pipeline"
  type        = list(string)
}

variable "application_pipeline_codebuild_project_name" {
  description = "Name of the CodeBuild project the Build stage invokes"
  type        = string
}

variable "application_pipeline_codebuild_project_arn" {
  description = "ARN of that same CodeBuild project — scopes the role's StartBuild grant"
  type        = string
  validation {
    condition     = can(regex("^arn:aws:codebuild:", var.application_pipeline_codebuild_project_arn))
    error_message = "application_pipeline_codebuild_project_arn must be a CodeBuild project ARN."
  }
}