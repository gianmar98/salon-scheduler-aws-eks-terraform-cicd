# `dynamodb` module

Provisioned-capacity DynamoDB table for the salon scheduler's announcements banner.
Wraps `terraform-aws-modules/dynamodb-table/aws` 5.5.0.

## Item shape

The Django view (`appointments/views.py`) scans this table and reads one string
attribute per item:

```python
announcements = dynamodb.scan(TableName=...)
context["announcements"] = [a['Contents']['S'] for a in announcements['Items']]
```

So every item needs:

| Attribute | Type | Role |
|---|---|---|
| `Timestamp` | S | partition key (declared in `attributes`), e.g. `20240701` |
| `Contents` | S | the banner text the template renders |

Only the partition key is declared in Terraform — DynamoDB is schemaless for
everything else, so `Contents` is written by the application, not by this module.

## Inputs

All 11 are supplied by the env layer; validation lives here, not there.

| Name | Type | Note |
|---|---|---|
| `announcements_dynamo_db_table_name` | string | env-suffixed by the caller |
| `announcements_table_hash_partition_key` | string | changing it **replaces the table** |
| `announcements_table_class` | string | `STANDARD` \| `STANDARD_INFREQUENT_ACCESS` |
| `announcements_table_RCU` | number | ≥ 2 |
| `announcements_table_WCU` | number | ≥ 2 |
| `announcements_table_pitr_enabled` | bool | |
| `announcements_table_deletion_protection` | bool | `true` makes `destroy` fail |
| `announcements_table_autoscaling_enabled` | bool | ⚠️ toggling **recreates the table** |
| `announcements_table_min_RWcapacity` | number | ≥ 2 |
| `announcements_table_max_RWcapacity` | number | ≤ 20 |
| `announcements_table_target_scaling_val` | number | AWS accepts 20–90 |

## Outputs

| Name | Value |
|---|---|
| `announcements_table_name` | table id/name |
| `announcements_table_arn` | table ARN — grant this to the app's IAM role |

## Gotchas

- Flipping `announcements_table_autoscaling_enabled` swaps the upstream resource
  address (`aws_dynamodb_table.this` ↔ `aws_dynamodb_table.autoscaled`), which
  **recreates the table and loses data**. Use `terraform state mv`, not a blind apply.
- `announcements_table_deletion_protection = true` makes `terraform destroy` fail on
  this table until it is set back to `false` **and applied**. Budget an extra apply
  when tearing the env down.