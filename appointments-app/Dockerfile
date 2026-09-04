# Provided by the Amazon Cloud Institute (ACI) as Capstone 2 Lab 05 material.
# The instructions below are ACI's; the explanatory comments are ACI's with some added
# by this repository's author. See NOTICE.
#
# Author's changes to the ACI original:
#   - python:3.11-slim -> python:3.12-slim, to match the local venv
#   - apt -> apt-get with --no-install-recommends and the package-list cleanup
#
# Not baked in on purpose: DATABASE_HOST, DATABASE_USER, DATABASE_DB_NAME,
# AWS_DEFAULT_REGION, LIBMYSQL_ENABLE_CLEARTEXT_PLUGIN=1. Without all five the app
# silently falls back to an empty SQLite file inside the container. Pass them with
# `docker run -e`, and from the pod spec on EKS.

#Base image used. Lightweight python image
FROM python:3.12-slim

#Ports the app is listening on
EXPOSE 8088

#Updated package lists and installs the necessary packages for building and installing Python
#   that depend on MySQL client libs
#   rm the package lists in this SAME RUN: each instruction freezes its own layer, so
#   deleting them later would hide the ~40MB without removing it from the image
RUN apt-get update && apt-get install -y --no-install-recommends \
      gcc pkg-config default-libmysqlclient-dev \
    && rm -rf /var/lib/apt/lists/*

#Sets working Dir
WORKDIR /app

#Copies requirements.txt file form local dir to /app dir inside container
COPY requirements.txt /app

#Instapp Python dependencies in requirements.txt using pip3.
#   --no-cache-dir makes sure package cache is not used that can help reduce imgae size
RUN pip3 install -r requirements.txt --no-cache-dir

#Copy Django project's manage.py file to /app dir inside container
COPY manage.py /app/

#Copy hairdresser_django dir to /app/hairdresser_django dir inside container
COPY hairdresser_django/ /app/hairdresser_django/

#Copy appointments dir (app code) to /app/appointments dir inside container
COPY appointments/ /app/appointments

#Entry point for container to be the python3 command
ENTRYPOINT ["python3"]

#Specifies default command to be executed when container starts. In this case run django dev server
# binding it to 0.0.0.0 address (listen on all available ENIs) and port 8088
CMD ["manage.py", "runserver", "0.0.0.0:8088"]