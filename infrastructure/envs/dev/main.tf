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