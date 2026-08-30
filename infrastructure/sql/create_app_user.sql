-- Copyright (c) 2026 Giancarlo Martinez
-- SPDX-License-Identifier: Apache-2.0
--
-- Creates the DB user Django authenticates as with an IAM token.
--
-- Terraform cannot do this: creating a MySQL user is a SQL statement, not an AWS API
-- call. Run this once after `terraform apply` builds a fresh instance. It is idempotent,
-- so re-running it is safe.
--
-- The username and database name are hardcoded and MUST match
-- appointments_db_iam_username and appointments_db_name in envs/dev/terraform.tfvars.
--
--
-- SETUP (once per machine)
-- ------------------------
--   brew install mysql-client@8.0
--
-- The 8.0 client is required. MySQL 9.x dropped mysql_native_password, which is how the
-- RDS-managed master user authenticates, so a 9.x client fails with
-- "ERROR 2059: Authentication plugin 'mysql_native_password' cannot be loaded".
--
--
-- RUN THIS FILE (after every rebuild of the instance)
-- --------------------------------------------------
--   cd infrastructure/envs/dev
--   MYSQL_PWD=$(aws secretsmanager get-secret-value \
--     --secret-id "$(terraform output -raw appointments_db_master_user_secret_arn)" \
--     --query SecretString --output text | jq -r .password) \
--   /opt/homebrew/opt/mysql-client@8.0/bin/mysql \
--     -h "$(terraform output -raw appointments_db_address)" \
--     -u salonadmin salon < ../../sql/create_app_user.sql
--
-- Expected output — no banner, no table borders, just this:
--
--   user                plugin                   ssl_type
--   appointments_admin  AWSAuthenticationPlugin  ANY
--
--
-- OPEN AN INTERACTIVE SHELL (to browse the database by hand)
-- ---------------------------------------------------------
-- The same command without the `< ../../sql/create_app_user.sql` at the end:
--
--   cd infrastructure/envs/dev
--   MYSQL_PWD=$(aws secretsmanager get-secret-value \
--     --secret-id "$(terraform output -raw appointments_db_master_user_secret_arn)" \
--     --query SecretString --output text | jq -r .password) \
--   /opt/homebrew/opt/mysql-client@8.0/bin/mysql \
--     -h "$(terraform output -raw appointments_db_address)" \
--     -u salonadmin salon
--
-- Then `SHOW TABLES;` — empty until `manage.py migrate` has run against RDS.
--
--
-- NOTES
-- -----
-- * `cd infrastructure/envs/dev` is required: `terraform output` only works from the
--   directory holding the state, and both commands call it twice.
-- * MYSQL_PWD keeps the password off the command line, so it stays out of `ps` and out
--   of your shell history.
-- * To change an existing user (e.g. to add REQUIRE SSL), CREATE USER IF NOT EXISTS will
--   not touch it. Drop it first: DROP USER 'appointments_admin'@'%';

-- Create the account. No password: it accepts a signed IAM token instead.
-- REQUIRE SSL because that token crosses the wire in cleartext.
CREATE USER IF NOT EXISTS 'appointments_admin'@'%'
  IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS'
  REQUIRE SSL;

-- Without this it can log in but touch nothing (ERROR 1044).
GRANT ALL PRIVILEGES ON salon.* TO 'appointments_admin'@'%';

-- Verify. Expect ALL PRIVILEGES ON `salon`.* and ssl_type ANY.
SHOW GRANTS FOR 'appointments_admin'@'%';
SELECT user, plugin, ssl_type FROM mysql.user WHERE user = 'appointments_admin';


-- Not run by this file. Paste manually when needed:
--   DROP USER 'appointments_admin'@'%';                 -- delete account (data untouched)
--   REVOKE ALL PRIVILEGES ON salon.* FROM 'appointments_admin'@'%';
--   SELECT user, host, plugin, ssl_type FROM mysql.user;  -- list all accounts
