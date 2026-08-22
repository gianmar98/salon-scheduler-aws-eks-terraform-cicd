# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

# DynamoDB ---------------------------------------------------------------------------
variable "announcements_dynamo_db_table_name" {
  description = "Name of the announcements DynamoDB table"
  type        = string
}

variable "announcements_table_hash_partition_key" {
  description = "Hash/Partition key of the announcements table"
  type        = string
}

variable "announcements_table_class" {
  description = "Storage class for the announcements DynamoDB table. Allowed: STANDARD, STANDARD_INFREQUENT_ACCESS."
  type        = string
  validation {
    condition     = contains(["STANDARD", "STANDARD_INFREQUENT_ACCESS"], var.announcements_table_class)
    error_message = "announcements_table_class must be one of: STANDARD, STANDARD_INFREQUENT_ACCESS."
  }
}

variable "announcements_table_RCU" {
  description = "Read Capacity Units for the announcements table"
  type        = number
  validation {
    condition     = var.announcements_table_RCU >= 2
    error_message = "RCU must be at least 2"
  }
}

variable "announcements_table_WCU" {
  description = "Write Capacity Units for the announcements table"
  type        = number
  validation {
    condition     = var.announcements_table_WCU >= 2
    error_message = "WCU must be at least 2"
  }
}

variable "announcements_table_pitr_enabled" {
  description = "Enable point-in-time recovery (continuous rolling backup) on the announcements table"
  type        = bool
}

variable "announcements_table_deletion_protection" {
  description = "Block DeleteTable on the announcements table. When true, terraform destroy fails on this table until it is set back to false and applied."
  type        = bool
}

variable "announcements_table_autoscaling_enabled" {
  description = "Enable autoscaling on the announcements table"
  type        = bool
}

variable "announcements_table_min_RWcapacity" {
  description = "Minimum autoscaling capacity for the announcements table"
  type        = number
  validation {
    condition     = var.announcements_table_min_RWcapacity >= 2
    error_message = "Min R/W capacity must be at least 2"
  }
}

variable "announcements_table_max_RWcapacity" {
  description = "Maximum autoscaling capacity for the announcements table"
  type        = number
  validation {
    condition     = var.announcements_table_max_RWcapacity <= 20
    error_message = "Max R/W capacity must be at most 20"
  }
}

variable "announcements_table_target_scaling_val" {
  description = "Target % of provisioned capacity to trigger autoscaling"
  type        = number
  # NOTE: DynamoDB target-tracking itself only accepts 20-90. This range is deliberately
  # wider than AWS allows, so a value like 5 passes validate and fails at apply instead.
  validation {
    condition     = var.announcements_table_target_scaling_val >= 1 && var.announcements_table_target_scaling_val <= 100
    error_message = "Target scaling value must be between 1 and 100."
  }
}