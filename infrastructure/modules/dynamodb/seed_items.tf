# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

resource "aws_dynamodb_table_item" "seed_announcements" {
  for_each = var.announcements_table_seed_items

  table_name = module.announcements_table.dynamodb_table_id
  hash_key   = var.announcements_table_hash_partition_key
  item = jsonencode({
    (var.announcements_table_hash_partition_key) = { S = each.key },
    Contents                                     = { S = each.value }
  })

}