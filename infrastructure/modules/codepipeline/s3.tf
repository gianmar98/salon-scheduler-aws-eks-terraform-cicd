# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

# Stages hand work to each other through this bucket: Source writes the repo zip, Build
# reads it. Required by CodePipeline
module "artifacts_s3_bucket" {
  source        = "terraform-aws-modules/s3-bucket/aws"
  version       = "5.12.0"
  bucket        = var.application_pipeline_artifact_bucket_name
  force_destroy = true

  # Required by CodePipeline — it reads artifacts by version ID.
  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  # Every run writes another copy of the repo; without expiry they accumulate forever.
  lifecycle_rule = [
    {
      id      = "expire-artifacts"
      enabled = true
      # Abandoned multipart uploads are invisible in the console but still billed.
      abort_incomplete_multipart_upload_days = 7
      expiration                             = { days = var.application_pipeline_artifact_retention_days }
      noncurrent_version_expiration          = { days = var.application_pipeline_artifact_retention_days }
    }
  ]

  #BLOCK PUBLIC ACCESS IS DEFAULT
}