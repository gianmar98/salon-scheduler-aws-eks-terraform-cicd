# `codebuild` module

CodeBuild project that lints and unit-tests the Django app on every push to `main`
that touches `appointments-app/`.

## What it runs

The build recipe is not in this module — it lives in the repository at
`appointments-app/buildspec_unittest.yml`, and CodeBuild reads it from the cloned
source at build time. This module only stores the path.

That split is deliberate: build steps change far more often than infrastructure, so
editing a `pylint` flag shouldn't require a `terraform apply`.

The buildspec runs pylint, then coverage over the Django test suite, and publishes two
report groups:

| Report group | Source file | Format |
|---|---|---|
| `UnitTests` | `unittests.xml` | JUnit, written by the `xmlrunner` test runner |
| `NewCoverage` | `coverage.xml` | Cobertura, written by `coverage xml` |

## Inputs

All 11 are supplied by the env layer; validation lives here, not there.

| Name | Type | Note |
|---|---|---|
| `unittest_codebuild_project_name` | string | env-suffixed by the caller; changing it **replaces the project** and renames the role, both policies, the log group, and the report groups |
| `unittest_codebuild_codeconnection_arn` | string | the CodeConnections connection to GitHub; the role is granted `UseConnection` on it |
| `unittest_codebuild_source_location` | string | `https://github.com/<owner>/<repo>` — a trailing `/tree/<branch>` breaks the clone |
| `unittest_codebuild_source_version` | string | branch, tag, or commit |
| `unittest_codebuild_buildspec` | string | path from the **repo root**, not from this module |
| `unittest_codebuild_image` | string | must ship the Python the buildspec requests |
| `unittest_codebuild_compute_type` | string | `BUILD_GENERAL1_SMALL` \| `MEDIUM` \| `LARGE` |
| `unittest_codebuild_build_timeout` | number | 5–480 minutes |
| `unittest_codebuild_log_retention_days` | number | CloudWatch retention; `0` keeps logs forever |
| `unittest_codebuild_artifact_bucket_name` | string | the pipeline's artifact bucket; the role reads the source zip from it |
| `unittest_codebuild_webhook_branch_pattern` | string | **unused** while `webhook.tf` is commented out |
| `unittest_codebuild_webhook_file_path_pattern` | string | **unused** while `webhook.tf` is commented out |

## What it creates

| Resource | Purpose |
|---|---|
| `aws_codebuild_project.unittest` | the build project |
| `aws_iam_role.unittest` | service role, trusted by `codebuild.amazonaws.com` |
| `aws_iam_policy.unittest_base` + attachment | logs, artifact buckets, reports |
| `aws_iam_policy.unittest_codeconnections` + attachment | source clone through CodeConnections |
| `aws_cloudwatch_log_group.unittest` | `/aws/codebuild/<project>`, with retention |
| `aws_codebuild_webhook.unittest` | **commented out** — see "Who triggers this project" below |
| `aws_codebuild_report_group.unittest` | `UnitTests` (TEST) and `NewCoverage` (CODE_COVERAGE) |

The CodeConnections connection and the `aws_codebuild_source_credential` that registers
it are **not** here — they are account- and region-wide, shared with CodePipeline, so
they live in the env layer (`envs/dev/codeconnections.tf`). The module takes the
connection ARN as an input.

## Who triggers this project

**CodePipeline, not the webhook.** `webhook.tf` is commented out on purpose.

Both mechanisms worked, and having both meant every push to `appointments-app/` ran
the suite twice — once from `GitHub-Hookshot`, once from
`codepipeline/ApplicationPipeline-dev`, about six seconds apart. Same commit, same
report groups, twice the minutes.

The pipeline won because it can do everything the webhook did:

| | webhook | pipeline |
|---|---|---|
| branch filter | `HEAD_REF` filter | `trigger.git_configuration.push.branches` |
| path filter | `FILE_PATH` filter | `trigger.git_configuration.push.file_paths` |

The path filter is what keeps Terraform-only commits from running the Django tests, so
it had to survive the move. It lives in `modules/codepipeline` now, and needs
`pipeline_type = "V2"` — V1 silently ignores the `trigger` block.

Verified both directions: a commit touching `appointments-app/` produces exactly one
build with initiator `codepipeline/...`, and a commit touching only `infrastructure/`
produces none.

To go back to webhook-only, uncomment `webhook.tf` and drop the `trigger` block from the
pipeline. The two variables above are kept for that reason.

## One manual step before this module works

**The GitHub connection cannot be fully created by Terraform.** `apply` creates it in
`PENDING` status — an ARN with no authorization behind it. Completing the OAuth handshake
is browser-only, and no Terraform resource can flip it to `AVAILABLE`:

1. `terraform apply` — the connection is created, `PENDING`. Builds cannot clone yet.
2. AWS console → **Developer Tools → Settings → Connections** → select it → **Update
   pending connection**.
3. Install the **AWS Connector for GitHub** app and grant it the repository.
4. Status becomes `AVAILABLE`. Nothing else needs re-applying.

This is once per AWS account and region, not once per environment or project — a later
CodePipeline reuses the same connection.

The alternative is a GitHub personal access token
(`auth_type = "PERSONAL_ACCESS_TOKEN"`), which avoids the click but puts a long-lived
secret in config and state. Not used here.

Four statements across the two policies, each scoped to an ARN pattern built from the
project name rather than `"*"`:

| Policy | Grants | Scoped to |
|---|---|---|
| base | `logs:CreateLogGroup`, `CreateLogStream`, `PutLogEvents` | this project's log group and its streams |
| base | `s3:GetObject`, `PutObject`, `GetObjectVersion`, `GetBucketAcl`, `GetBucketLocation` | `codepipeline-<region>-*` buckets, for when this becomes a pipeline stage |
| base | the five `codebuild:*Report*` actions | `report-group/<project>-*` |
| connections | `GetConnection`, `GetConnectionToken`, `UseConnection` | the one connection ARN passed in |

Statements carry no `Sid` — see Pass 2 below.

Both the `codeconnections:` and legacy `codestar-connections:` ARNs are listed —
AWS renamed the service and still authorizes against either prefix depending on
the calling path.

## Outputs

| Name | Value |
|---|---|
| `unittest_codebuild_project_name` | project name |
| `unittest_codebuild_project_arn` | project ARN |
| `unittest_codebuild_service_role_arn` | service role ARN |
| `unittest_codebuild_log_group_name` | log group name |

## Provenance

Everything here started in the AWS console: the project, its service role, the two
policies the console attached, the log group and report groups CodeBuild created on the
first build, the webhook, and the GitHub connection. All twelve objects are now under
Terraform, adopted in three passes. Nothing was recreated and nothing was left orphaned.

### Pass 1 — the project, with generated config

An `import` block plus `terraform plan -generate-config-out` wrote the HCL. It was
parameterized into this module and relocated with a `moved` block, verified by a plan
reporting no changes.

Two things that cost time and are worth recording:

- **The import ID is the project ARN, not the project name.** Passing the name fails
  with `could not parse import ID as ARN: arn: invalid prefix`. The block builds the
  ARN from `aws_caller_identity` / `aws_region` rather than hardcoding an account ID.
- **`-generate-config-out` emits config the provider then rejects.** It wrote
  `concurrent_build_limit = 0` for an unset optional integer, which fails the
  provider's own `>= 1` validation. The generator does not run validators against its
  output, so expect a cleanup pass.

The same import plan surfaced unrelated drift in the `dynamodb` module: the table's
Application Auto Scaling targets had been deregistered by AWS when the table was
replaced during the partition-key change. Terraform never noticed, because the new
table reused the name and `resource_id` (`table/Announcement-dev`) was unchanged — so
there was no diff to detect. State claimed the targets existed; AWS had dropped them.
Refreshing during the import caught it, and the same apply re-registered them.

### Pass 2 — the IAM role, policies, and log group, with hand-written config

The same generate-then-clean loop was not worth repeating for five small IAM resources.
Their live shape was read straight out of the API instead:

```bash
aws iam get-role --role-name codebuild-unittest-dev-service-role
aws iam list-attached-role-policies --role-name codebuild-unittest-dev-service-role
aws iam get-policy-version --policy-arn <arn> --version-id <default>
aws logs describe-log-groups --log-group-name-prefix /aws/codebuild/unittest-dev
```

`iam.tf` was then written by hand to match, and `import` blocks pointed at it. Writing
first is what let the names stay derived from `var.unittest_codebuild_project_name`
instead of hardcoded — `-generate-config-out` would have baked the account ID, the
region, and the console's generated policy names into committed config, and undoing
that is most of the work the generator saves.

The console's naming is reproduced exactly so the import matches:

| Resource | Name | Path |
|---|---|---|
| role | `codebuild-<project>-service-role` | `/service-role/` |
| base policy | `CodeBuildBasePolicy-<project>-<region>` | `/service-role/` |
| connections policy | `CodeBuildCodeConnectionsSourceCredentialsPolicy-<project>-<region>-<account>` | `/service-role/` |
| log group | `/aws/codebuild/<project>` | — |

Attachment import IDs are `<role-name>/<policy-arn>`, not an ARN of their own.

The verification is the plan: **6 to import, 0 to add, 0 to destroy.** Both policy
documents matched with no diff, which is the real proof the hand-written statements are
faithful. The only changes were deliberate — `default_tags` reaching resources the
console left untagged, log retention moving off `Never expire`, and `group_name` pinned
on the project's `cloudwatch_logs` block.

Statement `Sid`s were left out on purpose. The console writes none, and adding them
would have shown up as a policy diff on import — a cosmetic change disguised as drift.

### Pass 3 — webhook, report groups, and the GitHub connection

Written by hand the same way, from `batch-get-projects`, `batch-get-report-groups`, and
`list-source-credentials`. Result: **5 to import, 0 to add, 0 to destroy**, with only
`default_tags` and an explicit `delete_reports = false` as diffs.

- **The webhook's import ID is the project name**, not an ARN — it is a child of the
  project, not a standalone resource.
- **Report groups are created implicitly**, named `<project>-<key>` from the buildspec's
  `reports:` keys. `local.report_groups` in `reports.tf` has to stay in sync with the
  buildspec; nothing enforces that.
- **`aws_codebuild_source_credential` cannot be imported cleanly.** The API never
  returns `token`, so it stays null in state, and because `token` is ForceNew every plan
  wants to destroy and recreate the credential. `lifecycle { ignore_changes = [token] }`
  is what stops the perpetual diff. Swapping the connection means tainting it by hand.

## Gotchas

- **Renaming the project renames almost everything.** The role, both policies, the log
  group, and both report groups derive their names from
  `unittest_codebuild_project_name`, so changing it replaces seven objects, not one.
- **`local.report_groups` must match the buildspec's `reports:` keys.** Nothing checks
  this. Add a report group to the buildspec without adding it here and CodeBuild will
  create it outside Terraform, exactly as it did originally.
- **The log group cannot simply be declared.** CodeBuild creates
  `/aws/codebuild/<project>` implicitly on the first build, so a plain `resource` block
  fails with `ResourceAlreadyExistsException`. It has to be imported, or the group
  deleted first.
- **The build's working directory persists across phases.** `INSTALL` and `BUILD` share
  one cwd, so a bare `cd appointments-app` in both makes the second one fail. The
  buildspec uses `cd $CODEBUILD_SRC_DIR/appointments-app`, which is idempotent.
- **pylint needs `PYTHONPATH=.`** to import the Django settings module. Without it the
  root `__init__.py` makes pylint put the *parent* directory on `sys.path`, and the run
  dies inside `pylint_django` with a misleading `AttributeError`.