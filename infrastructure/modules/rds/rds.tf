# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

resource "aws_db_instance" "default" {
  identifier           = var.appointments_db_identifier
  allocated_storage    = var.appointments_db_allocated_storage
  db_name              = var.appointments_db_name
  engine               = var.appointments_db_engine
  engine_version       = var.appointments_db_engine_version
  instance_class       = var.appointments_db_instance_class
  username             = var.appointments_db_username
  parameter_group_name = var.appointments_db_parameter_group_name
  skip_final_snapshot  = var.appointments_db_skip_final_snapshot

  # RDS generates the master password and owns it in Secrets Manager, so it never
  # reaches tfvars or state. Not a tfvars dial: setting this to false requires a
  # password argument that no longer exists.
  manage_master_user_password = true
}