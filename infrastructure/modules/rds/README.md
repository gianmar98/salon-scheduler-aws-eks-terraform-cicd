# `rds` module

Single RDS instance intended to replace the Django app's `db.sqlite3` for development.
Written directly in Terraform — **not** console-first-then-import like `codebuild`.

Deliberately minimal: one `aws_db_instance` plus the security group that gates it. No
subnet group and no parameter group of its own — everything not needed to hold data was
left out.

## What it creates

| Resource | Purpose |
|---|---|
| `aws_db_instance.salon_rds_mysql` | the instance; master password owned by RDS in Secrets Manager |
| `aws_security_group.rds_sg` | the access gate — one ingress rule, no egress |
| `aws_vpc_security_group_ingress_rule.mysql_from_client` | opens the DB port to a single client IP |
| `aws_vpc_security_group_ingress_rule.mysql_from_eks` | opens the DB port to the EKS node security group; skipped when EKS is off |
| `data.http.myip` | resolves the applying machine's public IP |
| `mysql_user.app` | the application's login, created with `AWSAuthenticationPlugin` |
| `mysql_grant.app` | that login's privileges — DML on one database, nothing else |

## Inputs

All 17 are supplied by the env layer; validation lives here, not there.

| Name | Type | Note |
|---|---|---|
| `appointments_db_identifier` | string | env-suffixed by the caller |
| `appointments_db_allocated_storage` | number | ≥ 20 — the gp2/gp3 floor |
| `appointments_db_name` | string | initial database created inside the instance |
| `appointments_db_engine` | string | `mysql` \| `postgres` |
| `appointments_db_engine_version` | string | must match the parameter group's family |
| `appointments_db_instance_class` | string | |
| `appointments_db_username` | string | master username |
| `appointments_db_iam_username` | string | the application's login — token auth, never a password; also passed to the `eks` module as `eks_app_db_user` |
| `appointments_db_parameter_group_name` | string | `default.<engine><version>` unless a custom group exists |
| `appointments_db_skip_final_snapshot` | bool | `true` for dev |
| `appointments_db_publicly_accessible` | bool | public DNS name; the SG is the real gate |
| `appointments_db_iam_auth_enabled` | bool | lets `AWSAuthenticationPlugin` users log in with a token; grants nothing on its own |
| `appointments_db_apply_immediately` | bool | `true` in dev; `false` defers changes to the maintenance window |
| `appointments_db_vpc_id` | string | VPC the security group is created in |
| `appointments_db_port` | number | engine port, and the port opened in the SG |
| `appointments_db_eks_allowed_security_group_id` | string | EKS node SG allowed inbound; `null` when EKS is off |
| `appointments_db_eks_ingress_enabled` | bool | whether that rule is created — `var.eks_enabled`, passed straight through |

There is **no password input, by design** — see below. There is also **no allowed-CIDR
input**: the ingress rule derives it from `data.http.myip`.

`appointments_db_eks_allowed_security_group_id` is computed in the env layer from the `eks`
module's output and so never passes through `terraform.tfvars`. It arrives as `null` when
`eks_enabled = false`.

**`appointments_db_eks_ingress_enabled` exists because `count` has to be known at plan
time.** The obvious version of that `count` tests the SG id for `null` — and on a cold
cluster the id is not `null`, it is *unknown*, because the cluster is being created in the
same run. The comparison then yields unknown too, and the apply dies with "The `count`
value depends on resource attributes that cannot be determined until apply." A bool read
from `terraform.tfvars` carries no such uncertainty. The two inputs have to stay in sync:
the flag decides whether the rule exists, the id is what it points at.

## Outputs

| Name | Value |
|---|---|
| `appointments_db_address` | hostname — Django's `DATABASES` `HOST` |
| `appointments_db_port` | port — `PORT` |
| `appointments_db_name` | initial database — `NAME` |
| `appointments_db_resource_id` | immutable `db-XXXX` ID — what `rds-db:connect` is authorized against, not the identifier |
| `appointments_db_master_user_secret_arn` | Secrets Manager secret holding the master password |

## The password is never in Terraform

`manage_master_user_password = true`. RDS generates a 28-character password, stores it in
a Secrets Manager secret it owns (`rds!db-<resource-id>`), and rotates it.

This is the only option where the secret stays out of the state file. The alternatives
all fail the same way:

- `sensitive = true` on a variable only redacts **CLI output**. State still holds plaintext.
- A hand-written Secrets Manager secret puts the value back in state via the resource.
- Reading an out-of-band secret with `data.aws_secretsmanager_secret_version` also lands
  in state — Terraform persists every data source result.

The rule: anything Terraform reads *or* sets is in state, in the clear. The only escape
is Terraform never handling the value.

**`manage_master_user_password` is not a tfvars dial.** Setting it to `false` would
require a `password` argument that no longer exists, so it is hardcoded rather than
offered as a knob that cannot actually be turned.

Consequence: the password cannot be retrieved from Terraform. To connect, read it from
the secret ARN in the outputs.

## Cost decisions

`db.t4g.micro` · 20 GB · Single-AZ · no Performance Insights · no enhanced monitoring ·
no storage autoscaling. ≈ **$11.68 instance + $2.30 storage = $14/mo** in `us-east-1`
running 24/7, or $0 if the account is still inside the 12-month RDS free tier.

- **`db.t4g.micro`, not `db.t3.micro`** — $0.016/hr vs $0.018 for the same size.
- **20 GiB, not 10** — gp2/gp3 has a 20 GiB minimum; RDS rejects anything smaller.
- **The console's cheapest visible option is misleading.** It defaults to filtered lists;
  `db.r7g.large` ($0.239/hr, ~$174/mo) is what shows under Aurora, Multi-AZ DB cluster,
  or the "Memory optimized classes" radio. `db.t4g.micro` needs engine PostgreSQL/MySQL
  + Single DB instance + **Burstable classes**.
- **The real lever is uptime, not configuration.** A stopped instance bills storage only
  (~$2.30/mo). `aws_db_instance` does not manage run state, so stopping it out-of-band
  causes no drift. AWS force-starts after 7 days.

## Gotchas

- **`identifier` must be set.** Without it AWS generates a random `terraform-2026…`
  name, breaking the env-suffix convention every other module follows.
- **Reachability needs two things, not one.** `publicly_accessible` alone only assigns a
  public DNS name; the security group decides who may open a connection. Left at the
  defaults the instance lands in the default VPC security group, whose only ingress rule
  is self-referencing — it admits resources already in that group, not clients.
- **The allowed IP is whichever machine ran `apply`.** `data.http.myip` is resolved at
  plan time, so applying from a different network silently repoints the rule, and a CI
  `apply` would hand access to the build agent and lock out the laptop. Home ISPs also
  rotate addresses — when connections start timing out, re-apply.
- **A successful `apply` does not mean the change took effect.** With
  `apply_immediately = false`, RDS accepts `ModifyDBInstance` and parks the change in
  `PendingModifiedValues` until the maintenance window. Terraform reports success and the
  console keeps showing the old value — this is what made `iam_auth` look like it had not
  applied. `aws rds describe-db-instances --db-instance-identifier salon-db-dev` shows the
  pending block.
- **The SG's `description` is immutable.** It interpolates `appointments_db_identifier`,
  so changing the identifier replaces the security group while it is attached to a live
  instance.
- **`backup_retention_period` is unset, so it is 0** — automated backups are off. Backup
  storage up to the allocated size is **free**, so 1–7 days costs nothing and is the
  difference between "persistent" and one bad migration from total loss.
- **`storage_encrypted` is unset, so it is `false`.** Enabling it is free but requires a
  snapshot-and-restore once the instance exists — cheap to fix now, painful later.
- **Enabling IAM auth grants nobody anything.** `iam_database_authentication_enabled` only
  makes token login *possible*. A DB user created `WITH AWSAuthenticationPlugin` and an
  `rds-db:connect` policy are separate steps — see below.

## Connecting

Two steps, because Terraform cannot supply the password:

```bash
MYSQL_PWD=$(aws secretsmanager get-secret-value \
  --secret-id "$(terraform output -raw appointments_db_master_user_secret_arn)" \
  --query SecretString --output text | jq -r .password) \
mysql -h "$(terraform output -raw appointments_db_address)" -u salonadmin salon
```

`db_subnet_group_name` is not set — the instance uses the default VPC's default subnet
group.

### Checking what's in there

Once at the `mysql>` prompt:

```sql
SHOW TABLES;
SELECT * FROM appointments_hairdresser;
SELECT * FROM appointments_appointment;
```

Django names tables `<app>_<model>`, so the model is `Appointment` and the table is
`appointments_appointment` — singular. `SHOW TABLES` empty means `migrate` never ran
against RDS; `appointments_hairdresser` empty means it ran but `0002_populate` didn't.

### The app connects as a second, passwordless user

`salonadmin` above is the master account and is only used for administration. Django logs
in as `appointments_app`, which has no password at all — `mysql_user.app` creates it
`IDENTIFIED WITH AWSAuthenticationPlugin`, and it authenticates with a 15-minute IAM token
minted per connection.

Three pieces make that work:

- `mysql_user.app` and `mysql_grant.app` in this module — the `CREATE USER` and `GRANT`,
  run through the `petoju/mysql` provider. A rebuild is one `apply`, with no script to
  remember.
- `envs/dev/rds_iam_auth.tf` — the `rds-db:connect` policy for a *human* principal, scoped
  to `appointments_db_resource_id` and the one username, so a laptop can mint tokens for
  `migrate` and `dbshell`. It lives in the env layer because it names an account-specific
  IAM user.
- `modules/eks/pod_identity.tf` — the same `rds-db:connect` permission for the *application*,
  reaching the pods through their service account rather than an IAM user.

### The cost of managing the user in Terraform

The provider logs in as the master user, so `envs/dev/mysql_provider.tf` reads the
RDS-managed password out of Secrets Manager — **and Terraform state now contains it.** That
is the trade `CLAUDE.md` says not to make silently; this is the record of making it.

Two further consequences:

- The provider is configured from the instance's endpoint, which is unknown before the
  instance exists. On a cold account the first run must be
  `terraform apply -target=module.rds_db`, then a normal `apply`.
- It connects from wherever `apply` runs, so it depends on the one-IP ingress rule above.
  Applying from a different network fails until that rule catches up.

`tls` is set to `skip-verify` rather than `true`: RDS presents a certificate signed by an
Amazon RDS CA that is not in the system trust store, and verification fails outright. The
connection is still encrypted. Django's own connection operates at the same level —
`ssl_mode: REQUIRED` without CA pinning — so the two paths match. Pinning would mean
shipping the RDS CA bundle and refreshing it when AWS rotates.

`infrastructure/sql/create_app_user.sql` predates all of this and is no longer run by
anything. Its header is still a useful runbook for reaching the instance with the mysql
client by hand.

The Django side is done: `mysqlclient` and `django-iam-dbauth` in `requirements.txt`, and
a `DATABASES` block in `settings.py` that switches to RDS only when the `DATABASE_*`
variables are set, so the test suite and CI stay on SQLite. See
`appointments-app/COMMANDS.md` for the exact commands, including the mandatory
`LIBMYSQL_ENABLE_CLEARTEXT_PLUGIN=1`.

In the cluster those variables are set by `modules/eks/k8s_deployment.tf`, which reads
`appointments_db_address` from this module's outputs. A rebuilt instance gets a new
endpoint and the pods pick it up on the next `apply` — there is no manifest to edit.