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

All 8 are supplied by the env layer; validation lives here, not there.

| Name | Type | Note |
|---|---|---|
| `unittest_codebuild_project_name` | string | env-suffixed by the caller; changing it **replaces the project** |
| `unittest_codebuild_service_role_arn` | string | validated as an IAM role ARN; **not created by this module** |
| `unittest_codebuild_source_location` | string | `https://github.com/<owner>/<repo>` — a trailing `/tree/<branch>` breaks the clone |
| `unittest_codebuild_source_version` | string | branch, tag, or commit |
| `unittest_codebuild_buildspec` | string | path from the **repo root**, not from this module |
| `unittest_codebuild_image` | string | must ship the Python the buildspec requests |
| `unittest_codebuild_compute_type` | string | `BUILD_GENERAL1_SMALL` \| `MEDIUM` \| `LARGE` |
| `unittest_codebuild_build_timeout` | number | 5–480 minutes |

## Outputs

| Name | Value |
|---|---|
| `unittest_codebuild_project_name` | project name |
| `unittest_codebuild_project_arn` | project ARN |

## Provenance

This project was built in the AWS console first, then adopted into Terraform with an
`import` block and `terraform plan -generate-config-out`. The generated HCL was
parameterized into this module and relocated with a `moved` block, verified by a
plan reporting no changes.

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

## Gotchas

- **The webhook is not managed here.** It was created through the console alongside the
  project. Its filter group (`PUSH` + `^refs/heads/main$` + `^appointments-app/`) is
  what keeps Terraform-only commits from firing builds. Import it as a separate
  `aws_codebuild_webhook` resource to bring it under Terraform.
- **The service role is not managed here** either — the console generated it and this
  module takes its ARN as an input. Both gaps are known and intentional for now.
- **The build's working directory persists across phases.** `INSTALL` and `BUILD` share
  one cwd, so a bare `cd appointments-app` in both makes the second one fail. The
  buildspec uses `cd $CODEBUILD_SRC_DIR/appointments-app`, which is idempotent.
- **pylint needs `PYTHONPATH=.`** to import the Django settings module. Without it the
  root `__init__.py` makes pylint put the *parent* directory on `sys.path`, and the run
  dies inside `pylint_django` with a misleading `AttributeError`.