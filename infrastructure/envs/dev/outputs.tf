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
output "application_pipeline_name" {
  description = "Name of the CodePipeline pipeline"
  value       = module.application_pipeline.application_pipeline_name
}

output "application_pipeline_artifact_bucket_name" {
  description = "Artifact bucket the pipeline stages pass work through"
  value       = module.application_pipeline.application_pipeline_artifact_bucket_name
}

output "appointments_db_address" {
  description = "Hostname of the DB instance — Django's DATABASES HOST"
  value       = module.rds_db.appointments_db_address
}

output "appointments_db_port" {
  description = "Port the DB instance listens on — Django's DATABASES PORT"
  value       = module.rds_db.appointments_db_port
}

output "appointments_db_master_user_secret_arn" {
  description = "ARN of the RDS-managed Secrets Manager secret holding the master password"
  value       = module.rds_db.appointments_db_master_user_secret_arn
}

output "default_cidr_block" {
  description = "CIDR of default VPC"
  value       = data.aws_vpc.default.cidr_block
}
