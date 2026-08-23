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