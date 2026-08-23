# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

output "announcements_table_name" {
  description = "Name of the announcements DynamoDB table — the value the Django app must scan"
  value       = module.announcements_dynamo_db_table.announcements_table_name
}

output "announcements_table_arn" {
  description = "ARN of the announcements DynamoDB table — grant this to the app's IAM role"
  value       = module.announcements_dynamo_db_table.announcements_table_arn
}

output "unittest_codebuild_project_name" {
  description = "Name of the unit-test CodeBuild project"
  value       = module.unittest_codebuild_project.unittest_codebuild_project_name
}

output "unittest_codebuild_project_arn" {
  description = "ARN of the unit-test CodeBuild project"
  value       = module.unittest_codebuild_project.unittest_codebuild_project_arn
}