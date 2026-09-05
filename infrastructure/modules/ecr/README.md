# `ecr` module

Holds the container image for the Django app. The repository is the Terraform-managed
part; the image inside it is built and pushed by the pipeline's `BuildImage` stage, or
by hand from `appointments-app/` when testing locally.

Written directly in Terraform — one `aws_ecr_repository`, nothing else. No lifecycle
policy: each `:latest` push orphans the previous image as untagged, but at roughly
$0.10/GB-month on a ~500 MB image that is pennies. Now that the pipeline pushes on every
qualifying commit, untagged images accumulate faster than they did by hand — add
`aws_ecr_lifecycle_policy` if that starts to matter.

## What it creates

| Resource | Purpose |
|---|---|
| `aws_ecr_repository.appointments_app` | the repository the image is pushed to |

## Inputs

All 4 are supplied by the env layer; validation lives here, not there.

| Name | Type | Note |
|---|---|---|
| `appointments_ecr_repository_name` | string | env-suffixed by the caller |
| `appointments_ecr_image_tag_mutability` | string | `MUTABLE` \| `IMMUTABLE` |
| `appointments_ecr_scan_on_push` | bool | basic CVE scanning, free |
| `appointments_ecr_force_delete` | bool | `true` for dev, or destroy fails on a non-empty repo |

Encryption is not an input: ECR encrypts at rest with AES256 by default at no cost, and
the only alternative is a KMS key with its own charges.

## Outputs

| Name | Value |
|---|---|
| `appointments_ecr_repository_url` | registry URL to tag and push against |
| `appointments_ecr_repository_name` | repository name — what the ECR CLI commands take |
| `appointments_ecr_repository_arn` | repository ARN — what an IAM policy scopes push permissions to |

The first two exist so the account ID stays out of committed files and out of the push
commands. All three are consumed by `codebuild_buildimage`: the URL becomes `$ECR_REPO_URL`
inside the build, and the ARN scopes its push permissions to this one repository.

## Pushing

**Normally the pipeline does this.** A push to `main` touching `appointments-app/` runs
the unit tests, then the `BuildImage` stage builds and pushes three tags — `latest`,
`staging-test-image`, and the commit SHA. See `modules/codebuild_buildimage/README.md`.

The manual login/tag/push/verify commands below are still in
`appointments-app/COMMANDS.md`, and remain the fastest way to test a Dockerfile change
without waiting on a pipeline run.

## Building the image that lands here

Everything below runs from `appointments-app/`, the directory holding the `Dockerfile`.

### 1. Confirm the Docker daemon is up

```bash
docker info
```

Errors until Docker Desktop is running. Nothing else works before this succeeds.

### 2. Build the image

```bash
docker build -t appointments-app .
```

Docker reads the `Dockerfile` top to bottom, runs each instruction, and saves the result
as a read-only template. The trailing `.` is the **build context** — the directory Docker
may `COPY` from — which is why the command has to run from `appointments-app/` and not
the repo root. `-t` names the image.

First build takes minutes: it pulls `python:3.12-slim` and compiles `mysqlclient` from
source. Later builds are seconds, because each instruction is cached as its own layer and
only the layers below a changed line are rebuilt.

### 3. Confirm it was created

```bash
docker images
```

A row named `appointments-app` means the template is on disk. Nothing is running yet — an
image is a frozen filesystem, not a process.

### 4. Run a container against RDS

```bash
docker run -it --rm -p 8088:8088 -v ~/.aws:/root/.aws:ro -e AWS_DEFAULT_REGION=us-east-1 -e LIBMYSQL_ENABLE_CLEARTEXT_PLUGIN=1 -e DATABASE_HOST=$(terraform -chdir=../infrastructure/envs/dev output -raw appointments_db_address) -e DATABASE_USER=appointments_admin -e DATABASE_DB_NAME=salon appointments-app
```

A container is one running copy of the image.

| Flag | What it does |
|---|---|
| `-it` | keeps the terminal attached, so Django's log is visible and Ctrl-C stops it |
| `--rm` | deletes the container on exit, instead of leaving a stopped one behind |
| `-p 8088:8088` | forwards the host's port 8088 into the container's own network namespace — the only reason a browser can reach it |
| `-v ~/.aws:/root/.aws:ro` | shares AWS credentials into the container, read-only |
| `-e` | one environment variable each; five are required |
| `appointments-app` | the image. Anything after it would override the `CMD` |

Success looks like `Starting development server at http://0.0.0.0:8088/`, then a
`GET / 200` once the browser hits `http://localhost:8088`.

### 5. Prove it reached RDS

Book an appointment in the UI, then from a `mysql` session:

```sql
SELECT * FROM appointments_appointment;
```

A new row means the container minted an IAM auth token, connected over TLS, and wrote to
RDS — the point of the exercise. Without it the app may look fine while quietly writing to
a throwaway SQLite file inside the container.

## Gotchas

- **The container inherits no AWS credentials.** In the ACI lab the IDE runs on an EC2
  instance with an instance profile, so the container picks credentials up for free. A
  container on a laptop is fully isolated and sees nothing — hence the `~/.aws` mount.
  Without it, `django-iam-dbauth` cannot sign the RDS token. Add `-e AWS_PROFILE=<name>`
  if the credentials are not under `default`.
- **`LIBMYSQL_ENABLE_CLEARTEXT_PLUGIN=1` is required and the lab omits it.** The IAM token
  is sent as a cleartext password and the MySQL C library refuses that unless allowed.
  Without it: `(2059, "Authentication plugin 'mysql_clear_password' cannot be loaded")`.
- **An empty `DATABASE_HOST` fails as a *local socket* error, not a missing-host error.**
  `settings.py` only checks that the variable is *present*, so `-e DATABASE_HOST=` still
  selects the MySQL branch, and MySQLdb then falls back to
  `/run/mysqld/mysqld.sock` — `(2002, "Can't connect to local server through socket")`.
  The usual cause is the terminal breaking that long `docker run` line mid-command, so
  paste it whole.
- **The RDS security group still applies.** The container's traffic leaves through the
  host, so it arrives with the laptop's public IP. If that IP has rotated, connections
  time out until the env layer is re-applied.
- **Apple Silicon builds arm64 by default.** Fine locally. Pushing an image for x86 nodes
  needs `docker build --platform linux/amd64`, which emulates and is much slower — worth
  deferring until the target architecture is known. A mismatch surfaces at pod start as
  `exec format error`.
- **Migrations are not run by the container.** `CMD` is `runserver`; the schema has to
  exist already. See `appointments-app/COMMANDS.md`.