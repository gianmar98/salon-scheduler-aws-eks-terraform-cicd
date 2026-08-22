# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

output "announcements_table_name" {
  description = "Name of the announcements DynamoDB table"
  value       = module.announcements_table.dynamodb_table_id
}

output "announcements_table_arn" {
  description = "ARN of the announcements DynamoDB table"
  value       = module.announcements_table.dynamodb_table_arn
}