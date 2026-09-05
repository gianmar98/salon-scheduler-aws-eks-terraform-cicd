# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

output "appointments_ecr_repository_url" {
  description = "Registry URL to tag and push against — keeps the account ID out of commands"
  value       = aws_ecr_repository.appointments_app.repository_url
}

output "appointments_ecr_repository_name" {
  description = "Repository name — what the ECR CLI commands take"
  value       = aws_ecr_repository.appointments_app.name
}

output "appointments_ecr_repository_arn" {
  description = "Repository ARN — what an IAM policy scopes push permissions to"
  value       = aws_ecr_repository.appointments_app.arn
}