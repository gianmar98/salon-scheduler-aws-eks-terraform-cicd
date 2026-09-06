# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

# ECR ---------------------------------------------------------------------------
variable "appointments_ecr_repository_name" {
  description = "Repository name — env-suffixed by the caller"
  type        = string
}

variable "appointments_ecr_image_tag_mutability" {
  description = "MUTABLE lets a tag be repointed to a new image; IMMUTABLE freezes it once used"
  type        = string

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.appointments_ecr_image_tag_mutability)
    error_message = "Tag mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "appointments_ecr_scan_on_push" {
  description = "Run a CVE scan of the image's OS packages on every push"
  type        = bool
}

variable "appointments_ecr_force_delete" {
  description = "Let destroy remove the repository while it still holds images"
  type        = bool
}

variable "appointments_ecr_untagged_expiry_days" {
  description = "Days an untagged image is kept before the lifecycle policy expires it. Tagged images are never selected."
  type        = number

  validation {
    condition     = var.appointments_ecr_untagged_expiry_days >= 1
    error_message = "appointments_ecr_untagged_expiry_days must be at least 1; ECR rejects 0."
  }
}