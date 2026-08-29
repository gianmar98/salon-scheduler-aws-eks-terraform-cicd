# `codepipeline` module

Two-stage pipeline that pulls the repo from GitHub and runs the `codebuild` module's
unit-test project against it.

```
Source (CodeStarSourceConnection)  →  Build (CodeBuild)
       writes source_output                reads source_output
```

No deploy stage. Nothing is shipped anywhere — the pipeline exists to run the tests.

## What it creates

| Resource | Purpose |
|---|---|
| `aws_codepipeline.application_pipeline` | the pipeline, `pipeline_type = "V2"` |
| `aws_iam_role.application_pipeline_role` | service role, trusted by `codepipeline.amazonaws.com` |
| `aws_iam_role_policy.application_pipeline` | artifact bucket, connection, and StartBuild on one project |
| `module.artifacts_s3_bucket` | the artifact store — `terraform-aws-modules/s3-bucket/aws` 5.12.0 |

The GitHub connection is **not** here. It is account- and region-wide and shared with
the `codebuild` module, so it lives in the env layer
(`envs/dev/codeconnections.tf`); this module takes its ARN as an input.

## The artifact store is mandatory

CodePipeline has no equivalent of CodeBuild's `NO_ARTIFACTS`. Stages never hand data to
each other directly — Source zips the repo into S3 and Build downloads it from there, so
the bucket is the mechanism, not a feature.

Two things follow:

- **Versioning must be on.** CodePipeline addresses artifacts by version ID.
- **The CodeBuild service role needs S3 access to this bucket.** The console originally
  scoped that grant to `codepipeline-<region>-*`; since the bucket here is named
  `aci-capstone2-pipeline-artifact-bucket`, the grant was repointed at it by name. The
  same string is passed to both modules from the env layer — a plain string rather than
  a resource reference, because referencing the bucket from `codebuild` while
  `codepipeline` references the CodeBuild project would be a dependency cycle.

Objects land at `<bucket>/<pipeline-name-truncated-to-20>/source_out/<random>` with no
`.zip` extension, which is why the console will not preview them. To inspect one:

```bash
aws s3 cp s3://<bucket>/ApplicationPipeline-/source_out/<id> /tmp/src.zip
unzip -l /tmp/src.zip
```

## Inputs

All 10 are supplied by the env layer; validation lives here, not there.

| Name | Type | Note |
|---|---|---|
| `application_pipeline_name` | string | env-suffixed by the caller; also names the role |
| `application_pipeline_execution_mode` | string | `QUEUED` \| `SUPERSEDED` \| `PARALLEL` |
| `application_pipeline_artifact_bucket_name` | string | globally unique; must match what `codebuild` is granted |
| `application_pipeline_artifact_retention_days` | number | > 0 |
| `application_pipeline_codeconnection_arn` | string | the GitHub connection the env layer owns |
| `application_pipeline_full_repository_id` | string | `<owner>/<repo>` — **not** a URL |
| `application_pipeline_branch_name` | string | used by both the Source action and the trigger |
| `application_pipeline_trigger_file_paths` | list(string) | globs, e.g. `["appointments-app/**"]` |
| `application_pipeline_codebuild_project_name` | string | from the codebuild module's output |
| `application_pipeline_codebuild_project_arn` | string | same project — scopes the `StartBuild` grant |

## Outputs

| Name | Value |
|---|---|
| `application_pipeline_name` | pipeline name |
| `application_pipeline_arn` | pipeline ARN |
| `application_pipeline_service_role_arn` | service role ARN |
| `application_pipeline_artifact_bucket_name` | artifact bucket name |
| `application_pipeline_artifact_bucket_arn` | artifact bucket ARN |

## Deviations from the ACI lab

The lab specifies CodeCommit and a pre-provisioned `CodePipelineRole`. Neither is
available here, so:

| Lab | Here | Why |
|---|---|---|
| CodeCommit repo as source | `CodeStarSourceConnection` to GitHub | CodeCommit is closed to new AWS accounts |
| CloudWatch Events change detection | the connection's own detection | EventBridge rules are the CodeCommit path; connection-based sources do not need one |
| Existing role `CodePipelineRole` | `aws_iam_role.application_pipeline_role` | that role is a lab-account fixture |

Everything else follows the lab: `SUPERSEDED`, a Source stage, a Build stage pointed at
the unit-test project, and no deploy stage.

## Gotchas

- **`trigger` requires `pipeline_type = "V2"`.** On V1 the block is accepted and then
  silently ignored, so the pipeline fires on every push to the branch and the file-path
  filter appears not to work.
- **Change detection has no path awareness of its own.** Without the `trigger` block the
  Source action rebuilds on any commit to the branch, Terraform-only commits included.
  This is the only place CodePipeline looks at which files changed.
- **The Build action declares no `output_artifacts`.** The buildspec produces reports,
  not artifacts, and there is no deploy stage to consume them. Naming an output artifact
  that never gets produced fails the action.
- **The CodeBuild project's own `source` and `artifacts` are ignored here.** When
  CodePipeline invokes a project it overrides both to type `CODEPIPELINE` at runtime, so
  the project's `GITHUB` source and `NO_ARTIFACTS` apply only to direct builds.
- **Renaming the pipeline renames its role.** Both derive from
  `application_pipeline_name`.
