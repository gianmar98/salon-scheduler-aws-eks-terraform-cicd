# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

# Lets an IAM principal mint a login token for one DB user, which is what Django's
# `use_iam_auth` does on every connection. The lab supplies this through the IDE's
# instance profile; on a laptop it has to be attached to the caller directly.
#
# Lives in the env layer rather than the module because it attaches to a named IAM
# principal in this account — the same reason codeconnections.tf sits here.
resource "aws_iam_policy" "rds_db_connect" {
  name        = "${var.appointments_db_identifier}${local.env_suffix}-connect"
  description = "Generate RDS IAM auth tokens for the ${var.appointments_db_iam_username} DB user"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "rds-db:connect" #To go log into DB with a token instead of password. When connecting it checks token against IAM
      # Authorized against the instance's resource ID, not its identifier — renaming the
      # instance keeps this valid, replacing it does not.
      Resource = "arn:aws:rds-db:${data.aws_region.currentUser.region}:${data.aws_caller_identity.currentUser.account_id}:dbuser:${module.rds_db.appointments_db_resource_id}/${var.appointments_db_iam_username}"
    }]
  })
}

resource "aws_iam_user_policy_attachment" "rds_db_connect" {
  user       = var.appointments_db_iam_principal
  policy_arn = aws_iam_policy.rds_db_connect.arn
}