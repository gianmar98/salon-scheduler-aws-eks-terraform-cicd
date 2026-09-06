# Command Reference

## Install dev dependencies

```bash
python3 -m pip install -r requirements-dev.txt
```

Installs everything listed in `requirements-dev.txt`, including `coverage` (used to measure test code coverage).

## Uninstall all pip packages

```bash
python3 -m pip freeze | xargs python3 -m pip uninstall -y
```

- `python3 -m pip freeze` — lists every installed package.
- `xargs python3 -m pip uninstall -y` — feeds that list to uninstall, answering yes to each.

Use to reset your Python environment to a clean state.

## Write installed packages to requirements.txt

With the venv activated:

```bash
python3 -m pip freeze > requirements.txt
```

Overwrites `requirements.txt` with every installed package pinned to its exact version — including transitive dependencies and dev-only tools. Activate the venv first, or you'll capture the global environment instead.

To add a single dependency without rewriting the file:

```bash
printf '\n' >> requirements.txt
echo "boto3~=1.43.78" >> requirements.txt
```

`requirements.txt` has no trailing newline, so the `printf` prevents the new entry from joining the last line.

## Check the Coverage.py version

```bash
coverage --version
```

Prints the installed version, confirming Coverage.py is installed and available. Coverage.py measures code coverage of Python programs — it tracks which lines run during execution and reports which lines could have run but didn't.

## Run coverage and generate an HTML report

In the IDE bash terminal:

```bash
cd appointments-app
coverage run --source='.' manage.py test appointments
coverage html
```

- `coverage run --source='.' manage.py test appointments` — runs the test suite while recording which lines execute, writing the raw data to `.coverage`.
- `coverage html` — turns that data into a browsable report in `htmlcov/`; open `htmlcov/index.html` to see line-by-line coverage.

## View the coverage report

After a coverage run:

```bash
open htmlcov/index.html
coverage report
```

- `open htmlcov/index.html` — opens the browsable, line-by-line report in your default browser (macOS; use `xdg-open` on Linux).
- `coverage report` — prints a per-file summary table in the terminal from the existing `.coverage` data.

## Check code and coverage in one step

Run after making code changes, from `~/environment/appointments-app`:

```bash
bash local_build.sh
```

Runs Pylint, then the coverage steps above. Pylint is a static analysis tool that catches undefined variables, syntax errors, and style issues before they reach a test run.

## Apply migrations to the local SQLite database

> **Run from `appointments-app/`, with the venv active.**

```bash
python3 manage.py migrate
```

Creates `db.sqlite3` and applies every migration, including `0002_populate.py`, which seeds three Services and two Hairdressers. The tests depend on that seed data, so this must run before `manage.py test` passes.

## Apply migrations to the RDS database

> **Run from `appointments-app/`, with the venv active.** The `-chdir` path below is
> relative to that directory, so it fails anywhere else.

```bash
LIBMYSQL_ENABLE_CLEARTEXT_PLUGIN=1 DATABASE_HOST=$(terraform -chdir=../infrastructure/envs/dev output -raw appointments_db_address) DATABASE_USER=appointments_admin DATABASE_DB_NAME=salon AWS_DEFAULT_REGION=us-east-1 python3 manage.py migrate
```

One line on purpose — the shell breaks this command if a backslash-continued paste picks up trailing whitespace.

- The three `DATABASE_*` variables are what `settings.py` checks — set together, they switch `DATABASES` from SQLite to `django_iam_dbauth.aws.mysql`. Miss one and Django silently uses SQLite instead.
- `AWS_DEFAULT_REGION` is required because the IAM auth token has to be signed for a region.
- `LIBMYSQL_ENABLE_CLEARTEXT_PLUGIN=1` is mandatory. The IAM token is sent as a cleartext password, and the MySQL C library refuses that unless told to allow it. `mysqlclient` exposes no setting for this, so the variable is the only way. Without it: `(2059, "Authentication plugin 'mysql_clear_password' cannot be loaded: plugin not enabled")`.
- No password anywhere: the engine mints a 15-minute token per connection as `appointments_admin`, which requires `rds-db:connect` on your IAM user.

The variables apply only to this command, so every other `manage.py` run stays on SQLite. Swap `migrate` for `runserver 0.0.0.0:8088` to run the app itself against RDS.

## Point the whole terminal session at RDS

> **Run from `appointments-app/`, with the venv active.**

```bash
export LIBMYSQL_ENABLE_CLEARTEXT_PLUGIN=1 DATABASE_HOST=$(terraform -chdir=../infrastructure/envs/dev output -raw appointments_db_address) DATABASE_USER=appointments_admin DATABASE_DB_NAME=salon AWS_DEFAULT_REGION=us-east-1
```

Then start the server as normal — it now writes to RDS:

```bash
python3 manage.py runserver 0.0.0.0:8088
```

Sets the variables once instead of prefixing every command, so `migrate` and `dbshell` use RDS too.

They live only in this terminal. Close it, or open a second tab, and you are back on SQLite — so check with `echo $DATABASE_HOST` if the app is writing rows you cannot find in MySQL. That is the usual cause: `runserver` started without these silently uses `db.sqlite3`.

This is a stand-in for what Terraform will do on EKS, where the same three `DATABASE_*` variables are set in the pod spec and the container always has them. Deliberately not added to `.bashrc`, so the default stays SQLite and the test suite is never pointed at a real database by accident.

## Build the Docker image

> **Run from `appointments-app/`.** No venv needed — the container builds its own.

```bash
docker build -t appointments-app .
```

Runs every instruction in the `Dockerfile` and saves the result as an image. The trailing
`.` is the build context — the directory Docker is allowed to `COPY` from — so this fails
from anywhere else. First build takes minutes (pulls Python, compiles `mysqlclient`);
later ones are seconds, since only layers below a changed line are rebuilt.

`docker images` lists what was created. An image is a frozen filesystem, not a process —
nothing runs until `docker run`.

## Run the container against RDS

> **Run from `appointments-app/`.** The `-chdir` path is relative to that directory.

```bash
docker run -it --rm -p 8088:8088 -v ~/.aws:/root/.aws:ro -e AWS_DEFAULT_REGION=us-east-1 -e LIBMYSQL_ENABLE_CLEARTEXT_PLUGIN=1 -e DATABASE_HOST=$(terraform -chdir=../infrastructure/envs/dev output -raw appointments_db_address) -e DATABASE_USER=appointments_admin -e DATABASE_DB_NAME=salon appointments-app
```

One line on purpose, like the migrate command above. Paste it whole — if the terminal
breaks it across lines, `DATABASE_HOST` ends up empty and the container fails with a
local-socket error instead of a missing-host one.

- `-it` — attaches the terminal, so Django's log shows and Ctrl-C stops the server.
- `--rm` — removes the container on exit rather than leaving a stopped one behind.
- `-p 8088:8088` — forwards the host port into the container's private network. Without it the browser cannot reach the app at all.
- `-v ~/.aws:/root/.aws:ro` — the container inherits no AWS credentials on a laptop, and `django-iam-dbauth` needs them to sign the RDS token. Read-only. Add `-e AWS_PROFILE=<name>` if the credentials are not under `default`.
- The five `-e` variables are the same ones the local `runserver` needs — the three `DATABASE_*` that `settings.py` checks, plus `AWS_DEFAULT_REGION` to sign the token and `LIBMYSQL_ENABLE_CLEARTEXT_PLUGIN=1` to let the driver send it.

Then open `http://localhost:8088`, book an appointment, and confirm it landed:
`SELECT * FROM appointments_appointment;`. That round trip is the proof the container
reached RDS — an empty or missing variable produces a working-looking app writing to a
throwaway SQLite file inside the container.

The container does not run migrations; `CMD` is `runserver`, so the schema must already
exist. See "Apply migrations to the RDS database" above.

## Push the image to ECR

> **Run from `appointments-app/`.** The `-chdir` path is relative to that directory.

**The pipeline normally does this.** A push to `main` touching `appointments-app/` runs
the tests, then the `BuildImage` stage builds and pushes `latest`, `staging-test-image`,
and the commit SHA. The commands below are for testing a Dockerfile change without
waiting on a pipeline run — they push the same `latest` tag, so whichever ran last wins.

Every command reads the registry from `terraform output`, so the account ID never appears
in anything committed.

**1. Authenticate Docker to the registry.**

```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(terraform -chdir=../infrastructure/envs/dev output -raw appointments_ecr_repository_url | cut -d/ -f1)
```

ECR has no permanent Docker password. `get-login-password` mints a 12-hour token and the
pipe hands it straight to `docker login` on stdin, so it never lands in shell history.
The `cut` trims the `/appointments-app-dev` path off the end — `docker login` takes a
registry hostname, not a repository path.

**2. Tag the local image with the registry name.**

```bash
docker tag appointments-app:latest $(terraform -chdir=../infrastructure/envs/dev output -raw appointments_ecr_repository_url):latest
```

Docker decides where to push from the image's *name*, not from a flag. `appointments-app`
has no registry in it, so it would go to Docker Hub. This adds a second name pointing at
the same image — no copy is made.

**3. Push.**

```bash
docker push $(terraform -chdir=../infrastructure/envs/dev output -raw appointments_ecr_repository_url):latest
```

**4. Verify it arrived.**

```bash
aws ecr describe-images --repository-name $(terraform -chdir=../infrastructure/envs/dev output -raw appointments_ecr_repository_name) --region us-east-1
```

Because the repository is `MUTABLE`, pushing `:latest` again repoints the tag and leaves
the previous image untagged rather than failing.

## Pull the pipeline's image and run it

> **Run from `appointments-app/`.** The `-chdir` paths are relative to that directory.

Every other section here runs an image built on this machine. This one runs the image
**CodeBuild** built, which is the only way to answer three questions the local workflow
cannot:

- Does the Dockerfile produce a working image in a clean build environment, not just one
  with a warm Docker cache and a developer's half-configured shell?
- Did the push and pull round trip preserve it intact?
- Does the image run somewhere other than the machine that built it?

Until an image survives that, "it works on my laptop" is all that has been proven.

### What happens before you type anything

A push to `main` touching `appointments-app/` runs three pipeline stages:

| Stage | What it does |
|---|---|
| Source | zips the repo into the artifact bucket |
| Build | unzips it, runs pylint and the Django tests |
| BuildImage | unzips it, runs `docker build`, applies three tags, pushes to ECR |

Then the image sits in ECR. **Nothing deploys it** — there is no EKS and no deploy stage
yet, so pulling it here is the only way to run what the pipeline produced. When a cluster
exists it will pull the same image the same way; these commands stand in for it.

### 1. Log in to the registry

```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(terraform -chdir=../infrastructure/envs/dev output -raw appointments_ecr_repository_url | cut -d/ -f1)
```

Same login as the manual push above — ECR has no permanent password, so this generates one
that lasts 12 hours.

### 2. Pull the image

```bash
docker pull $(terraform -chdir=../infrastructure/envs/dev output -raw appointments_ecr_repository_url):latest
```

`latest` points at whichever build pushed most recently.

### 3. Run it against RDS

```bash
docker run -it --rm -p 8088:8088 -v ~/.aws:/root/.aws:ro -e AWS_DEFAULT_REGION=us-east-1 -e LIBMYSQL_ENABLE_CLEARTEXT_PLUGIN=1 -e DATABASE_HOST=$(terraform -chdir=../infrastructure/envs/dev output -raw appointments_db_address) -e DATABASE_USER=appointments_admin -e DATABASE_DB_NAME=salon $(terraform -chdir=../infrastructure/envs/dev output -raw appointments_ecr_repository_url):latest
```

Identical to "Run the container against RDS" above except the image name is the ECR URL
instead of the local `appointments-app`. The same five environment variables are required
for the same reasons.

Then open `http://localhost:8088`, book an appointment, and confirm it landed:
`SELECT * FROM appointments_appointment;`. A new row is the proof — the pipeline's image
reached RDS.

### The platform warning is expected

```
WARNING: The requested image's platform (linux/amd64) does not match the detected host
platform (linux/arm64/v8) and no specific platform was requested
```

Apple Silicon Macs are `arm64`; CodeBuild runs on Intel/AMD hardware and builds `amd64`.
Those are different instruction sets, so Docker translates as it runs — it works, just
slower to start. Nothing is wrong.

It is worth knowing which way round this matters. **The pipeline building `amd64` is the
correct outcome**, because EKS nodes are normally `amd64` too. An image built on the Mac
and pushed by hand would be `arm64` and would fail on a node with `exec format error`.
The laptop is the odd one out here, not the pipeline. To build an x86 image locally,
`docker build --platform linux/amd64` emulates — correct, but much slower.

### Why each flag is here

The short version of these commands — the one that assumes a preconfigured cloud IDE —
does not work on a laptop. Four differences, each with a failure attached:

| Choice | Alternative | Why it is wrong here |
|---|---|---|
| `terraform output` for the registry | hardcoded `<account>.dkr.ecr...` | the account ID would end up in a committed file, and the repository name carries an env suffix Terraform generates |
| `-v ~/.aws:/root/.aws:ro` | omit it | a container inherits no credentials on a laptop. On EC2 it would pick up the instance profile for free; here `django-iam-dbauth` has nothing to sign the RDS token with |
| `-e DATABASE_HOST=$(...)` | bare `-e DATABASE_HOST` | the bare form forwards the variable from the shell, and only works if it was exported first. Empty is worse than missing: `settings.py` checks only that the variable is *present*, so an empty host still selects MySQL and then fails as a confusing local-socket error |
| `-e LIBMYSQL_ENABLE_CLEARTEXT_PLUGIN=1` | omit it | the IAM token travels as a cleartext password and the MySQL C library refuses to send one unless allowed. Without it: `(2059, "Authentication plugin 'mysql_clear_password' cannot be loaded")` |

If the container hangs at "Performing system checks..." the RDS connection is stalling,
not the image — usually the security group, after a home IP rotation. Re-apply the env
layer to repoint it.

## Run the dev app server

```bash
python3 manage.py runserver 0.0.0.0:8088
```

Starts Django's development server on port 8088, bound to all interfaces (`0.0.0.0`) so it's reachable from outside the machine — e.g. the Cloud9/EC2 preview — not just `localhost`. Ctrl-C to stop.