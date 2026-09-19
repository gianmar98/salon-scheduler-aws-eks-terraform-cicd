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

output "appointments_ecr_repository_url" {
  description = "Registry URL to tag and push the container image against"
  value       = module.ecr.appointments_ecr_repository_url
}

output "appointments_ecr_repository_name" {
  description = "Repository name — what the ECR CLI commands take"
  value       = module.ecr.appointments_ecr_repository_name
}

output "appointments_db_master_user_secret_arn" {
  description = "ARN of the RDS-managed Secrets Manager secret holding the master password"
  value       = module.rds_db.appointments_db_master_user_secret_arn
}

# output "default_cidr_block" {
#   description = "CIDR of default VPC"
#   value       = data.aws_vpc.default.cidr_block
# }

output "aws_subnets" {
  description = "Subnets of us-east-1a,b,c from default vpc of current region"
  value       = data.aws_subnets.eks_subnets.ids
}

output "eks_app_url" {
  description = "Public URL of the application — the load balancer the Service provisions"
  value       = try(module.eks[0].app_url, null)
}

output "eks_kubeconfig_command" {
  description = "Command to point kubectl at the cluster — rerun after every rebuild, the endpoint and CA change each time"
  value       = try(module.eks[0].kubeconfig_command, null)
}
