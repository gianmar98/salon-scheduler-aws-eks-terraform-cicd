# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

output "unittest_codebuild_project_name" {
  description = "Name of the unit-test CodeBuild project"
  value       = aws_codebuild_project.unittest.name
}

output "unittest_codebuild_project_arn" {
  description = "ARN of the unit-test CodeBuild project"
  value       = aws_codebuild_project.unittest.arn
}

output "unittest_codebuild_service_role_arn" {
  description = "ARN of the IAM service role this module creates for the project"
  value       = aws_iam_role.unittest.arn
}

output "unittest_codebuild_log_group_name" {
  description = "CloudWatch log group the project writes build logs to"
  value       = aws_cloudwatch_log_group.unittest.name
}