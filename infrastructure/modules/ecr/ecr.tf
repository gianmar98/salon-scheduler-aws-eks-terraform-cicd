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

# Cleanup -----------------------------------------------------------------------------
# Every build pushes latest, staging-test-image, and the commit SHA. When the next build
# moves the first two, the old image keeps its SHA tag — so it stays tagged and this rule
# never touches it. What does go untagged is an image whose SHA tag got taken too, which
# happens when two builds race on the same commit.
#
# tagStatus = "untagged" cannot select an image that has any tag, so nothing reachable by
# name is ever at risk. Rules evaluate within 24 hours, not on push.
resource "aws_ecr_lifecycle_policy" "appointments_app" {
  repository = aws_ecr_repository.appointments_app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Expire untagged images after ${var.appointments_ecr_untagged_expiry_days} days"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = var.appointments_ecr_untagged_expiry_days
      }
      action = { type = "expire" }
    }]
  })
}