#!/bin/bash
# Python code standards
echo ==== PyLint checking ====
pylint --load-plugins pylint_django --django-settings-module=hairdresser_django.settings --ignore=migrations appointments/ --ignore-patterns=".*~.*"

# Coverage reports
echo ==== Code Coverage Report ====
coverage run --source='.' manage.py test appointments 
coverage html
