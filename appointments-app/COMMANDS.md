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

## Check code and coverage in one step

Run after making code changes, from `~/environment/appointments-app`:

```bash
. local_build.sh
```

Runs Pylint, then the coverage steps above. Pylint is a static analysis tool that catches undefined variables, syntax errors, and style issues before they reach a test run.