# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

output "application_pipeline_name" {
  description = "Name of the CodePipeline pipeline"
  value       = aws_codepipeline.application_pipeline.name
}

output "application_pipeline_arn" {
  description = "ARN of the CodePipeline pipeline"
  value       = aws_codepipeline.application_pipeline.arn
}

output "application_pipeline_service_role_arn" {
  description = "ARN of the IAM service role the pipeline assumes"
  value       = aws_iam_role.application_pipeline_role.arn
}

output "application_pipeline_artifact_bucket_name" {
  description = "Name of the artifact bucket stages pass work through"
  value       = module.artifacts_s3_bucket.s3_bucket_id
}

output "application_pipeline_artifact_bucket_arn" {
  description = "ARN of the artifact bucket — grant this to any stage's role"
  value       = module.artifacts_s3_bucket.s3_bucket_arn
}