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
  source                              = "../../modules/codebuild"
  unittest_codebuild_project_name     = "${var.unittest_codebuild_project_name}${local.env_suffix}"
  unittest_codebuild_service_role_arn = var.unittest_codebuild_service_role_arn
  unittest_codebuild_source_location  = var.unittest_codebuild_source_location
  unittest_codebuild_source_version   = var.unittest_codebuild_source_version
  unittest_codebuild_buildspec        = var.unittest_codebuild_buildspec
  unittest_codebuild_image            = var.unittest_codebuild_image
  unittest_codebuild_compute_type     = var.unittest_codebuild_compute_type
  unittest_codebuild_build_timeout    = var.unittest_codebuild_build_timeout
}

# moved {
#   from = aws_codebuild_project.unittest
#   to   = module.unittest_codebuild_project.aws_codebuild_project.unittest
# }