# Command Reference

## `python3 -m pip install -r requirements-dev.txt`
Installs all dev dependencies listed in `requirements-dev.txt`, including `coverage` (used to measure test code coverage).

## `python3 -m pip freeze | xargs python3 -m pip uninstall -y`
Lists every installed pip package and uninstalls each one. Use to reset your Python environment to a clean state.

## `coverage --version`
Prints the installed version of Coverage.py, confirming it's installed and available. Coverage.py measures code coverage of Python programs — it tracks which lines run during execution and reports which lines could have run but didn't.
