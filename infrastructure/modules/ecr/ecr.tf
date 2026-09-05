# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

# ECR ---------------------------------------------------------------------------------
resource "aws_ecr_repository" "appointments_app" {
  name = var.appointments_ecr_repository_name

  # MUTABLE lets a tag be moved to a different image: pushing :latest again repoints it
  # and leaves the old image untagged. IMMUTABLE freezes a tag once used, so a deployed
  # version can never be swapped underneath
  image_tag_mutability = var.appointments_ecr_image_tag_mutability

  image_scanning_configuration {
    # CVE scan of the image's OS packages on every push
    scan_on_push = var.appointments_ecr_scan_on_push
  }

  # Without this, destroy fails with RepositoryNotEmptyException while images remain and
  # they have to be deleted by hand.
  force_delete = var.appointments_ecr_force_delete
}