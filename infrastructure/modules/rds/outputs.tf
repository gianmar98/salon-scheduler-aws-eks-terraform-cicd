# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

output "appointments_db_address" {
  description = "Hostname of the DB instance — Django's DATABASES HOST"
  value       = aws_db_instance.default.address
}

output "appointments_db_port" {
  description = "Port the DB instance listens on — Django's DATABASES PORT"
  value       = aws_db_instance.default.port
}

output "appointments_db_name" {
  description = "Name of the initial database — Django's DATABASES NAME"
  value       = aws_db_instance.default.db_name
}

output "appointments_db_master_user_secret_arn" {
  description = "ARN of the RDS-managed Secrets Manager secret holding the master password"
  value       = aws_db_instance.default.master_user_secret[0].secret_arn
}