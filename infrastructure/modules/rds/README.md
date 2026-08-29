# `rds` module

Single RDS instance intended to replace the Django app's `db.sqlite3` for development.
Written directly in Terraform — **not** console-first-then-import like `codebuild`.

Deliberately minimal: one `aws_db_instance`, no subnet group, no security group, no
parameter group of its own. Everything not needed to hold data was left out.

## What it creates

| Resource | Purpose |
|---|---|
| `aws_db_instance.salon_rds_mysql` | the instance; master password owned by RDS in Secrets Manager |
| `aws_security_group.rds_sg` | the access gate — one ingress rule, no egress |
| `aws_vpc_security_group_ingress_rule.mysql_from_client` | opens the DB port to a single client IP |
| `data.http.myip` | resolves the applying machine's public IP |

## Inputs

All 14 are supplied by the env layer; validation lives here, not there.

| Name | Type | Note |
|---|---|---|
| `appointments_db_identifier` | string | env-suffixed by the caller |
| `appointments_db_allocated_storage` | number | ≥ 20 — the gp2/gp3 floor |
| `appointments_db_name` | string | initial database created inside the instance |
| `appointments_db_engine` | string | `mysql` \| `postgres` |
| `appointments_db_engine_version` | string | must match the parameter group's family |
| `appointments_db_instance_class` | string | |
| `appointments_db_username` | string | master username |
| `appointments_db_parameter_group_name` | string | `default.<engine><version>` unless a custom group exists |
| `appointments_db_skip_final_snapshot` | bool | `true` for dev |
| `appointments_db_publicly_accessible` | bool | public DNS name; the SG is the real gate |
| `appointments_db_iam_auth_enabled` | bool | lets `AWSAuthenticationPlugin` users log in with a token; grants nothing on its own |
| `appointments_db_apply_immediately` | bool | `true` in dev; `false` defers changes to the maintenance window |
| `appointments_db_vpc_id` | string | VPC the security group is created in |
| `appointments_db_port` | number | engine port, and the port opened in the SG |

There is **no password input, by design** — see below. There is also **no allowed-CIDR
input**: the ingress rule derives it from `data.http.myip`.

## Outputs

| Name | Value |
|---|---|
| `appointments_db_address` | hostname — Django's `DATABASES` `HOST` |
| `appointments_db_port` | port — `PORT` |
| `appointments_db_name` | initial database — `NAME` |
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
- **`versions.tf` declares an unused `awscc` provider.** Pre-existing; nothing here uses it.
- **The resource is named `default`**, not a descriptive noun, unlike the rest of the repo.

## Connecting

Two steps, because Terraform cannot supply the password:

```bash
MYSQL_PWD=$(aws secretsmanager get-secret-value \
  --secret-id "$(terraform output -raw appointments_db_master_user_secret_arn)" \
  --query SecretString --output text | jq -r .password) \
mysql -h "$(terraform output -raw appointments_db_address)" -u salonadmin salon
```

`db_subnet_group_name` is not set — the instance uses the default VPC's default subnet
group (`default-vpc-06e1e9ba608319136`).

The Django side — `mysqlclient`, env-driven `DATABASES` with a SQLite fallback so CI
keeps using SQLite — is not started. Note that making `settings.py` env-driven puts
original work under `appointments-app/`, which requires a `NOTICE` update in the same
change.