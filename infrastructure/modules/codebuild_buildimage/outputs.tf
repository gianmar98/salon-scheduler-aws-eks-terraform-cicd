# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

output "buildimage_codebuild_project_name" {
  description = "Name of the image-build CodeBuild project"
  value       = aws_codebuild_project.buildimage.name
}

output "buildimage_codebuild_project_arn" {
  description = "ARN of the image-build CodeBuild project"
  value       = aws_codebuild_project.buildimage.arn
}

output "buildimage_codebuild_service_role_arn" {
  description = "ARN of the IAM service role this module creates for the project"
  value       = aws_iam_role.buildimage.arn
}

output "buildimage_codebuild_log_group_name" {
  description = "CloudWatch log group the project writes build logs to"
  value       = aws_cloudwatch_log_group.buildimage.name
}