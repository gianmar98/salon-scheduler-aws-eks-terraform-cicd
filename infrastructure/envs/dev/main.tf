# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.4"
    }
  }
}

data "aws_caller_identity" "currentUser" {}
data "aws_region" "currentUser" {}

locals {
  env_suffix = "-${var.project_environment}"
}

provider "aws" {
  region = var.project_region
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.project_environment
      Owner       = var.project_owner
      ManagedBy   = "Terraform"
    }
  }
}

module "announcements_dynamo_db_table" {
  source                                  = "../../modules/dynamodb"
  announcements_dynamo_db_table_name      = "${var.announcements_dynamo_db_table_name}${local.env_suffix}"
  announcements_table_class               = var.announcements_table_class
  announcements_table_RCU                 = var.announcements_table_RCU
  announcements_table_WCU                 = var.announcements_table_WCU
  announcements_table_autoscaling_enabled = var.announcements_table_autoscaling_enabled
  announcements_table_pitr_enabled        = var.announcements_table_pitr_enabled
  announcements_table_deletion_protection = var.announcements_table_deletion_protection
  announcements_table_hash_partition_key  = var.announcements_table_hash_partition_key
  announcements_table_max_RWcapacity      = var.announcements_table_max_RWcapacity
  announcements_table_min_RWcapacity      = var.announcements_table_min_RWcapacity
  announcements_table_target_scaling_val  = var.announcements_table_target_scaling_val
}

module "unittest_codebuild_project" {
  source                                  = "../../modules/codebuild"
  unittest_codebuild_project_name         = "${var.unittest_codebuild_project_name}${local.env_suffix}"
  unittest_codebuild_codeconnection_arn   = aws_codeconnections_connection.github.arn
  unittest_codebuild_source_location      = var.unittest_codebuild_source_location
  unittest_codebuild_source_version       = var.unittest_codebuild_source_version
  unittest_codebuild_buildspec            = var.unittest_codebuild_buildspec
  unittest_codebuild_image                = var.unittest_codebuild_image
  unittest_codebuild_compute_type         = var.unittest_codebuild_compute_type
  unittest_codebuild_build_timeout        = var.unittest_codebuild_build_timeout
  unittest_codebuild_log_retention_days   = var.unittest_codebuild_log_retention_days
  unittest_codebuild_artifact_bucket_name = "${var.application_pipeline_artifact_bucket_name}${local.env_suffix}"

  unittest_codebuild_webhook_branch_pattern    = var.unittest_codebuild_webhook_branch_pattern
  unittest_codebuild_webhook_file_path_pattern = var.unittest_codebuild_webhook_file_path_pattern
}

module "application_pipeline" {
  source                                       = "../../modules/codepipeline"
  application_pipeline_name                    = "${var.application_pipeline_name}${local.env_suffix}"
  application_pipeline_execution_mode          = var.application_pipeline_execution_mode
  application_pipeline_artifact_bucket_name    = "${var.application_pipeline_artifact_bucket_name}${local.env_suffix}"
  application_pipeline_artifact_retention_days = var.application_pipeline_artifact_retention_days
  application_pipeline_full_repository_id      = var.application_pipeline_full_repository_id
  application_pipeline_branch_name             = var.application_pipeline_branch_name
  application_pipeline_trigger_file_paths      = var.application_pipeline_trigger_file_paths

  #External
  application_pipeline_codeconnection_arn     = aws_codeconnections_connection.github.arn
  application_pipeline_codebuild_project_name = module.unittest_codebuild_project.unittest_codebuild_project_name
  application_pipeline_codebuild_project_arn  = module.unittest_codebuild_project.unittest_codebuild_project_arn
}

# moved {
#   from = aws_codebuild_project.unittest
#   to   = module.unittest_codebuild_project.aws_codebuild_project.unittest
# }