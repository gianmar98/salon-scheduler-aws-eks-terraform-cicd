# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

module "announcements_table" {
  source  = "terraform-aws-modules/dynamodb-table/aws"
  version = "5.5.0"

  name     = var.announcements_dynamo_db_table_name
  hash_key = var.announcements_table_hash_partition_key #Partition Key
  #range_key = "" #Sort Key not required

  attributes = [
    {
      name = var.announcements_table_hash_partition_key #Partition Key
      type = "S"                                        # String
    }
  ]

  billing_mode = "PROVISIONED" #Capacity Mode
  table_class  = var.announcements_table_class

  read_capacity  = var.announcements_table_RCU
  write_capacity = var.announcements_table_WCU

  # PITR keeps a continuous rolling backup, so a bad write or an accidental DeleteItem is
  # recoverable - restores go to a NEW table, never over this one.
  point_in_time_recovery_enabled = var.announcements_table_pitr_enabled

  # Blocks DeleteTable at the API level, so terraform destroy fails instead of dropping the table.
  deletion_protection_enabled = var.announcements_table_deletion_protection

  autoscaling_enabled = var.announcements_table_autoscaling_enabled

  autoscaling_read = {
    scale_in_cooldown  = 50
    scale_out_cooldown = 40
    target_value       = var.announcements_table_target_scaling_val
    min_capacity       = var.announcements_table_min_RWcapacity
    max_capacity       = var.announcements_table_max_RWcapacity
  }

  autoscaling_write = {
    scale_in_cooldown  = 50
    scale_out_cooldown = 40
    target_value       = var.announcements_table_target_scaling_val
    min_capacity       = var.announcements_table_min_RWcapacity
    max_capacity       = var.announcements_table_max_RWcapacity
  }
}
