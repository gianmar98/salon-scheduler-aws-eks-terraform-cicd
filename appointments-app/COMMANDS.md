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

## Run the dev app server

```bash
python3 manage.py runserver 0.0.0.0:8088
```

Starts Django's development server on port 8088, bound to all interfaces (`0.0.0.0`) so it's reachable from outside the machine — e.g. the Cloud9/EC2 preview — not just `localhost`. Ctrl-C to stop.