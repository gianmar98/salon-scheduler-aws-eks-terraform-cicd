# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

# Project-wide ----------------------------------------------------------------------
variable "project_region" {
  description = "AWS region the project deploys to"
  type        = string
}

variable "project_environment" {
  description = "Environment name (e.g., dev, prod) — used in default_tags and the env suffix"
  type        = string
}

variable "project_name" {
  description = "Project name — used in default_tags"
  type        = string
}

variable "project_owner" {
  description = "Owner — used in default_tags"
  type        = string
}

# DYNAMODB ---------------------------------------------------------------------------
variable "announcements_dynamo_db_table_name" {
  description = "Name of the announcements DynamoDB table"
  type        = string
}

variable "announcements_table_hash_partition_key" {
  description = "Hash/Partition key of the announcements table"
  type        = string
}

variable "announcements_table_class" {
  description = "Storage class for the announcements DynamoDB table"
  type        = string
}

variable "announcements_table_RCU" {
  description = "Read Capacity Units for the announcements table"
  type        = number
}

variable "announcements_table_WCU" {
  description = "Write Capacity Units for the announcements table"
  type        = number
}

variable "announcements_table_pitr_enabled" {
  description = "Enable point-in-time recovery (continuous rolling backup) on the announcements table"
  type        = bool
}

variable "announcements_table_deletion_protection" {
  description = "Block DeleteTable on the announcements table"
  type        = bool
}

variable "announcements_table_autoscaling_enabled" {
  description = "Enable autoscaling on the announcements table"
  type        = bool
}

variable "announcements_table_min_RWcapacity" {
  description = "Minimum autoscaling capacity for the announcements table"
  type        = number
}

variable "announcements_table_max_RWcapacity" {
  description = "Maximum autoscaling capacity for the announcements table"
  type        = number
}

variable "announcements_table_target_scaling_val" {
  description = "Target % of provisioned capacity to trigger autoscaling"
  type        = number
}

# CODEBUILD --------------------------------------------------------------------------
variable "unittest_codebuild_project_name" {
  description = "Name of the CodeBuild project that lints and unit-tests the Django app"
  type        = string
}

variable "github_connection_name" {
  description = "Name of the CodeConnections connection to GitHub"
  type        = string
}

variable "unittest_codebuild_webhook_branch_pattern" {
  description = "Regex the pushed ref must match to fire a build"
  type        = string
}

variable "unittest_codebuild_webhook_file_path_pattern" {
  description = "Regex a changed file must match to fire a build"
  type        = string
}

variable "unittest_codebuild_log_retention_days" {
  description = "Days CloudWatch keeps the build logs"
  type        = number
}

variable "unittest_codebuild_source_location" {
  description = "HTTPS URL of the GitHub repository CodeBuild clones"
  type        = string
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
  description = "Managed CodeBuild image the build container runs"
  type        = string
}

variable "unittest_codebuild_compute_type" {
  description = "Build container size"
  type        = string
}

variable "unittest_codebuild_build_timeout" {
  description = "Minutes before CodeBuild aborts a running build"
  type        = number
}

# CODEPIPELINE -------------------------------------------------------------------------
variable "application_pipeline_name" {
  description = "Name of the CodePipeline pipeline"
  type        = string
}

variable "application_pipeline_execution_mode" {
  description = "How the pipeline handles concurrent executions"
  type        = string
}

variable "application_pipeline_artifact_bucket_name" {
  description = "Name of the S3 bucket stages pass artifacts through"
  type        = string
}

variable "application_pipeline_artifact_retention_days" {
  description = "Days before pipeline artifacts are expired"
  type        = number
}

variable "application_pipeline_full_repository_id" {
  description = "Repository the Source stage clones, as <owner>/<repo>"
  type        = string
}

variable "application_pipeline_branch_name" {
  description = "Branch the Source stage watches"
  type        = string
}

variable "application_pipeline_trigger_file_paths" {
  description = "Glob patterns a changed file must match to start the pipeline"
  type        = list(string)
}
