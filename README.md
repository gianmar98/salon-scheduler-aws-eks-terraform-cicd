# salon-scheduler-aws-eks-terraform-cicd

A Django appointment-booking app for a hair salon, with the AWS infrastructure and CI
that runs it defined in Terraform.

```
appointments-app/    Django app — ACI Capstone 2 starter code
infrastructure/      Terraform — modules/ + envs/dev
```

Authorship is split and the split matters: everything under `appointments-app/` was
provided by the Amazon Cloud Institute, everything under `infrastructure/` is original.
[`NOTICE`](NOTICE) records exactly which is which.

## What is built

| | |
|---|---|
| **App** | Django 5, SQLite locally, booking funnel of service → hairdresser → date → time |
| **Announcements** | banner text read from a DynamoDB table at request time |
| **Database** | RDS MySQL, reached with IAM token auth — no password in Terraform or in the app |
| **CI** | a three-stage CodePipeline — pull from GitHub, run pylint and the test suite, then build the container image — triggered only by pushes to `main` that touch `appointments-app/` |
| **Images** | built by CodeBuild and pushed to ECR as `latest`, `staging-test-image`, and the commit SHA |
| **Reports** | JUnit and Cobertura published to CodeBuild report groups on every run |
| **State** | S3 remote backend with lockfile |

Not built yet: EKS, and any deploy stage. The image reaches ECR and stops there. The
repository name describes the intended destination.

## Running the app locally

Requires Python 3.12 and AWS credentials able to read the DynamoDB table (the
announcements scan runs on every page load).

```bash
cd appointments-app
python3 -m venv .venv && source .venv/bin/activate
python3 -m pip install -r requirements-dev.txt

python3 manage.py migrate        # creates db.sqlite3 and seeds services/hairdressers
python3 manage.py runserver
```

`migrate` is not optional even for tests — the seed data ships as migration
`0002_populate.py`, and the test suite asserts against it with no fixtures.

Point the app at a different table with `ANNOUNCEMENTS_TABLE`; it defaults to
`Announcement-dev`.

### Tests, lint, coverage

```bash
python3 manage.py test appointments     # suite; also writes unittests.xml
./local_build.sh                        # pylint + coverage + HTML report in htmlcov/
```

`local_build.sh` is the gate, and mirrors what CodeBuild runs.
[`appointments-app/COMMANDS.md`](appointments-app/COMMANDS.md) has the annotated
command list.

## Deploying the infrastructure

Requires Terraform >= 1.10 and credentials for the target account.

**Before the first apply**, two things exist outside Terraform by necessity:

1. **The S3 state bucket.** Chicken-and-egg — the backend cannot create its own store.
   Create it, then set its name in `envs/dev/backend.tf`.
2. **`envs/dev/terraform.tfvars`.** Gitignored, because it carries the account ID. Copy
   the variable names from `envs/dev/variables.tf`.

Then:

```bash
cd infrastructure/envs/dev
terraform init
terraform plan
terraform apply
```

**After the first apply, one manual step is unavoidable.** The GitHub connection is
created in `PENDING` status and the OAuth handshake is browser-only — no Terraform
resource can authorize it. Go to **Developer Tools → Settings → Connections**, choose
the connection, click **Update pending connection**, and install the AWS Connector for
GitHub app. Until then builds cannot clone the repository. It is once per account and
region; a later CodePipeline reuses the same connection.

## Conventions

`infrastructure/` follows a strict modules/envs split: modules own their validation and
know nothing about environments, the env layer is pass-through and appends `-dev` to
names, and every tunable value is a `terraform.tfvars` entry rather than a hardcoded
default.

Each module's `README.md` is the source of truth for its inputs and its gotchas — start
there, not with the `.tf` files:

- [`modules/codebuild_unittest`](infrastructure/modules/codebuild_unittest/README.md) — pylint + tests
- [`modules/codebuild_buildimage`](infrastructure/modules/codebuild_buildimage/README.md) — Docker build + ECR push
- [`modules/codepipeline`](infrastructure/modules/codepipeline/README.md) — the three stages
- [`modules/dynamodb`](infrastructure/modules/dynamodb/README.md) — announcements table
- [`modules/ecr`](infrastructure/modules/ecr/README.md) — image repository
- [`modules/rds`](infrastructure/modules/rds/README.md) — MySQL instance and IAM auth

The unit-test CodeBuild stack was built in the AWS console first and adopted into
Terraform with `import` blocks — twelve objects, nothing recreated. That process, and
the traps in it, is written up under Provenance in
[`modules/codebuild_unittest`](infrastructure/modules/codebuild_unittest/README.md).
Everything since — the pipeline, RDS, ECR, and the image builder — was written directly
in Terraform.

## License

Apache 2.0 — see [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).