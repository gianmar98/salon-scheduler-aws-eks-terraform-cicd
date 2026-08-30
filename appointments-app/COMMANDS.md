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

## Run the dev app server

```bash
python3 manage.py runserver 0.0.0.0:8088
```

Starts Django's development server on port 8088, bound to all interfaces (`0.0.0.0`) so it's reachable from outside the machine — e.g. the Cloud9/EC2 preview — not just `localhost`. Ctrl-C to stop.