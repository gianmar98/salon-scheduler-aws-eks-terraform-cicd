# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

# Account-wide, not part of the codebuild module: CodePipeline and any future project
# authenticate to GitHub through this same connection.
resource "aws_codeconnections_connection" "github" {
  name          = var.github_connection_name
  provider_type = "GitHub"
}

# Registers the connection as CodeBuild's default GitHub credential for this region.
resource "aws_codebuild_source_credential" "github" {
  auth_type   = "CODECONNECTIONS"
  server_type = "GITHUB"
  token       = aws_codeconnections_connection.github.arn

  # The API never returns the token, so it stays null in state and every plan would
  # otherwise want to replace this. Change the connection and this needs recreating.
  lifecycle {
    ignore_changes = [token]
  }
}