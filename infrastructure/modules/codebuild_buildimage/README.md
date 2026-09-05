# `codebuild_buildimage` module

CodeBuild project that builds the Django app's container image and pushes it to ECR.

Written directly in Terraform. It started as a copy of `codebuild_unittest`, but the two
have diverged: this one publishes no reports, needs a Docker daemon, and needs ECR
permissions. The sibling module is the one that was adopted from the console with
`import` blocks — nothing here was.

## What it creates

| Resource | Purpose |
|---|---|
| `aws_codebuild_project.buildimage` | the project |
| `aws_iam_role.buildimage` | service role, trusted by `codebuild.amazonaws.com` |
| `aws_iam_policy.buildimage_base` + attachment | logs, artifact bucket, ECR push |
| `aws_iam_policy.buildimage_codeconnections` + attachment | clone GitHub through the connection |
| `aws_cloudwatch_log_group.buildimage` | `/aws/codebuild/<project>`, with retention |

No report groups: `buildspec_buildimage.yml` has no `reports:` section. No webhook — the
pipeline is the only trigger.

## What it runs

The recipe is not in this module. It lives at
`appointments-app/buildspecs/buildspec_buildimage.yml`, and CodeBuild reads it from the
cloned source at build time; the module only stores the path. Build steps change more
often than infrastructure, so editing a tag shouldn't require a `terraform apply`.

The buildspec logs in to ECR, builds the image, applies three tags, and pushes them:

| Tag | Meaning |
|---|---|
| `latest` | most recent successful build |
| `staging-test-image` | the lab's promotion step |
| `<commit-sha>` | `CODEBUILD_RESOLVED_SOURCE_VERSION` — traces an image back to exact code |

Because the repository is `MUTABLE`, re-pushing `latest` repoints the tag and leaves the
previous image untagged rather than failing.

## Two settings the buildspec cannot work without

- **`privileged_mode = true`.** The build already runs inside a container, and
  `docker build` starts Docker *inside* that container. That is blocked by default.
  Without it every build dies at `Cannot connect to the Docker daemon`. Hardcoded rather
  than offered as a tfvars dial — there is no working image builder with it off.
- **`ECR_REPO_URL`**, injected as an `environment_variable` from the `ecr` module's
  `appointments_ecr_repository_url` output. The buildspec uses it for the login, all
  three tags, and the push. Passing it in keeps the `-dev` suffix derived instead of
  written into a file that every environment shares.

## Inputs

All 12 are supplied by the env layer; validation lives here, not there.

| Name | Type | Note |
|---|---|---|
| `buildimage_codebuild_project_name` | string | env-suffixed by the caller; also names the role, both policies, and the log group |
| `buildimage_codebuild_codeconnection_arn` | string | the GitHub connection the env layer owns |
| `buildimage_codebuild_ecr_repository_url` | string | becomes `$ECR_REPO_URL` in the build |
| `buildimage_codebuild_ecr_repository_arn` | string | scopes the push permissions to one repository |
| `buildimage_codebuild_artifact_bucket_name` | string | the pipeline artifact bucket this project reads its source from |
| `buildimage_codebuild_log_retention_days` | number | must be a value CloudWatch accepts; 0 = forever |
| `buildimage_codebuild_source_location` | string | `https://github.com/<owner>/<repo>`, no trailing path |
| `buildimage_codebuild_source_version` | string | branch to check out **when a build runs** — not a trigger |
| `buildimage_codebuild_buildspec` | string | path from the **repo root**, not from this module |
| `buildimage_codebuild_image` | string | managed CodeBuild image |
| `buildimage_codebuild_compute_type` | string | `BUILD_GENERAL1_SMALL` \| `MEDIUM` \| `LARGE` |
| `buildimage_codebuild_build_timeout` | number | 5–480 minutes |

## Outputs

| Name | Value |
|---|---|
| `buildimage_codebuild_project_name` | project name — the pipeline's `ProjectName` |
| `buildimage_codebuild_project_arn` | project ARN — scopes the pipeline role's `StartBuild` |
| `buildimage_codebuild_service_role_arn` | service role ARN |
| `buildimage_codebuild_log_group_name` | log group the build writes to |

## IAM

| Policy | Actions | Scope |
|---|---|---|
| base | `logs:CreateLogGroup`, `CreateLogStream`, `PutLogEvents` | this project's log group |
| base | the five `s3:*` object/bucket reads | the pipeline artifact bucket |
| base | `ecr:GetAuthorizationToken` | `"*"` — registry-wide by definition, AWS rejects anything narrower |
| base | `BatchCheckLayerAvailability`, `InitiateLayerUpload`, `UploadLayerPart`, `CompleteLayerUpload`, `PutImage` | the one repository ARN |
| codeconnections | `GetConnectionToken`, `GetConnection`, `UseConnection` | the connection, under both its old and new service prefixes |

The five ECR push actions are `docker push` broken into the API calls it makes: ask which
layers already exist, start an upload, send bytes, finish, then write the manifest that
makes the tags real.

## Who triggers this project

**CodePipeline's `BuildImage` stage, and nothing else.** There is no `webhook.tf` here.
The pipeline runs `Source → Build (unit tests) → BuildImage`, so the image is only built
after the tests pass.

To run it on its own, without a push:

```bash
aws codebuild start-build --project-name buildimage-dev --region us-east-1
```

## Gotchas

- **`source_version` and `buildspec` are not triggers.** They say *what* to do when a
  build runs, never *when*. Only the pipeline stage starts a build.
- **The build's working directory persists across phases.** The buildspec uses
  `cd $CODEBUILD_SRC_DIR/appointments-app` because the Dockerfile is in a subdirectory —
  the ACI lab omits this, since in the lab the repo root *is* the app.
- **Renaming the project renames five other things.** The role, both policies, and the log
  group all derive from `buildimage_codebuild_project_name`.
- **The project's own `source` and `artifacts` are overridden at runtime.** CodePipeline
  forces both to type `CODEPIPELINE`, so the `GITHUB` source and `NO_ARTIFACTS` here apply
  only to direct `start-build` runs.
- **`local.report_groups` does not exist here on purpose.** If the buildspec ever gains a
  `reports:` section, the groups have to be declared or CodeBuild creates them outside
  Terraform.
