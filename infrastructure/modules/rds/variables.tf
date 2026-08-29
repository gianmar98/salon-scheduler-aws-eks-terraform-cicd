# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

# RDS ---------------------------------------------------------------------------------
variable "appointments_db_identifier" {
  description = "DB instance identifier — env-suffixed by the caller"
  type        = string
}

variable "appointments_db_allocated_storage" {
  description = "Allocated storage in GiB"
  type        = number

  validation {
    condition     = var.appointments_db_allocated_storage >= 20
    error_message = "General Purpose SSD storage has a 20 GiB minimum; RDS rejects anything smaller."
  }
}

variable "appointments_db_name" {
  description = "Name of the initial database created inside the instance"
  type        = string
}

variable "appointments_db_engine" {
  description = "Database engine"
  type        = string

  validation {
    condition     = contains(["mysql", "postgres"], var.appointments_db_engine)
    error_message = "Engine must be mysql or postgres."
  }
}

variable "appointments_db_engine_version" {
  description = "Engine version — must match the family of appointments_db_parameter_group_name"
  type        = string
}

variable "appointments_db_instance_class" {
  description = "Instance class"
  type        = string
}

variable "appointments_db_username" {
  description = "Master username"
  type        = string
}

variable "appointments_db_parameter_group_name" {
  description = "DB parameter group — the default.<engine><version> group unless a custom one exists"
  type        = string
}

variable "appointments_db_skip_final_snapshot" {
  description = "Skip the final snapshot on destroy — true for dev, false anywhere data matters"
  type        = bool
}