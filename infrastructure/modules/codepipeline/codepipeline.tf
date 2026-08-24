# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

resource "aws_codepipeline" "application_pipeline" {
  name     = var.application_pipeline_name
  role_arn = aws_iam_role.application_pipeline_role.arn



  #How pipeline processes multiple concurrent executions
  execution_mode = var.application_pipeline_execution_mode #SUPERSEDED: newer execution overtakes an older one

  artifact_store {
    location = module.artifacts_s3_bucket.s3_bucket_id
    type     = "S3"
  }


  #V2 is required for the trigger block to work
  pipeline_type = "V2"

  # Without this the pipeline fires on every push to the branch, Terraform-only commits
  # included. This is the only place CodePipeline looks at which files changed.
  trigger {
    provider_type = "CodeStarSourceConnection"

    git_configuration {
      source_action_name = "Source"

      push {
        branches {
          includes = [var.application_pipeline_branch_name]
        }

        file_paths {
          includes = var.application_pipeline_trigger_file_paths
        }
      }
    }
  }

  stage {
    name = "Source"

    # CodeStarSourceConnection clones through the GitHub connection and brings its own
    # change detection. The EventBridge rule the lab describes is the CodeCommit path.
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection" #AWS build-in source action pulls form Git host via CodeConnections connection (still named like old name CodeStartConnections)
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = var.application_pipeline_codeconnection_arn #aws_codeconnections_connection.github
        FullRepositoryId = var.application_pipeline_full_repository_id #github repo id
        BranchName       = var.application_pipeline_branch_name        #branch, main, etc...
      }
    }
  }

  stage {
    name = "Build"

    # No output_artifacts: the buildspec declares reports, not artifacts, and there is no
    # deploy stage to consume them. Naming one that is never produced fails the action.
    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source_output"]

      configuration = {
        ProjectName = var.application_pipeline_codebuild_project_name
      }
    }
  }
}