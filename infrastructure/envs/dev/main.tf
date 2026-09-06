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
data "aws_vpc" "default" {
  default = true
}
#default VPC has 1 subnet per AZ. limitation tied to region
data "aws_subnets" "eks_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "availability-zone"
    values = ["us-east-1a", "us-east-1b", "us-east-1c"]
  }
}

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
  source                                  = "../../modules/codebuild_unittest"
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
  application_pipeline_codeconnection_arn = aws_codeconnections_connection.github.arn
  #Unit test
  application_pipeline_codebuild_project_name = module.unittest_codebuild_project.unittest_codebuild_project_name
  application_pipeline_codebuild_project_arn  = module.unittest_codebuild_project.unittest_codebuild_project_arn
  #Build image
  application_pipeline_codebuild_buildimage_project_name = module.buildimage_codebuild_project.buildimage_codebuild_project_name
  application_pipeline_codebuild_buildimage_project_arn  = module.buildimage_codebuild_project.buildimage_codebuild_project_arn
}

module "rds_db" {
  source                               = "../../modules/rds"
  appointments_db_identifier           = "${var.appointments_db_identifier}${local.env_suffix}"
  appointments_db_allocated_storage    = var.appointments_db_allocated_storage
  appointments_db_name                 = var.appointments_db_name
  appointments_db_engine               = var.appointments_db_engine
  appointments_db_engine_version       = var.appointments_db_engine_version
  appointments_db_instance_class       = var.appointments_db_instance_class
  appointments_db_username             = var.appointments_db_username
  appointments_db_parameter_group_name = var.appointments_db_parameter_group_name
  appointments_db_skip_final_snapshot  = var.appointments_db_skip_final_snapshot
  appointments_db_publicly_accessible  = var.appointments_db_publicly_accessible
  appointments_db_iam_auth_enabled     = var.appointments_db_iam_auth_enabled
  appointments_db_apply_immediately    = var.appointments_db_apply_immediately
  appointments_db_port                 = var.appointments_db_port
  appointments_db_vpc_id               = data.aws_vpc.default.id
}

module "ecr" {
  source                                = "../../modules/ecr"
  appointments_ecr_repository_name      = "${var.appointments_ecr_repository_name}${local.env_suffix}"
  appointments_ecr_image_tag_mutability = var.appointments_ecr_image_tag_mutability
  appointments_ecr_scan_on_push         = var.appointments_ecr_scan_on_push
  appointments_ecr_force_delete         = var.appointments_ecr_force_delete
  appointments_ecr_untagged_expiry_days = var.appointments_ecr_untagged_expiry_days
}


module "buildimage_codebuild_project" {
  source                                    = "../../modules/codebuild_buildimage"
  buildimage_codebuild_project_name         = "${var.buildimage_codebuild_project_name}${local.env_suffix}"
  buildimage_codebuild_codeconnection_arn   = aws_codeconnections_connection.github.arn
  buildimage_codebuild_source_location      = var.buildimage_codebuild_source_location
  buildimage_codebuild_source_version       = var.buildimage_codebuild_source_version
  buildimage_codebuild_buildspec            = var.buildimage_codebuild_buildspec
  buildimage_codebuild_image                = var.buildimage_codebuild_image
  buildimage_codebuild_compute_type         = var.buildimage_codebuild_compute_type
  buildimage_codebuild_build_timeout        = var.buildimage_codebuild_build_timeout
  buildimage_codebuild_log_retention_days   = var.buildimage_codebuild_log_retention_days
  buildimage_codebuild_artifact_bucket_name = "${var.application_pipeline_artifact_bucket_name}${local.env_suffix}"

  #External
  buildimage_codebuild_ecr_repository_url = module.ecr.appointments_ecr_repository_url
  buildimage_codebuild_ecr_repository_arn = module.ecr.appointments_ecr_repository_arn
}

module "eks" {
  count            = var.eks_enabled ? 1 : 0
  source           = "../../modules/eks"
  eks_cluster_name = "${var.eks_cluster_name}${local.env_suffix}"

  #default subnets for 3 AZs in my default VPC
  eks_subnets_ids  = data.aws_subnets.eks_subnets.ids
}