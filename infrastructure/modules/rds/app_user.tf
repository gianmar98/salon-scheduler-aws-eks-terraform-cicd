# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

# Resource creates and manages a user on a MySQL server
resource "mysql_user" "app" {
  user        = var.appointments_db_iam_username
  host        = "%"                       #"%" = connect from anywhere.
  auth_plugin = "AWSAuthenticationPlugin" #no password for login so it accepts AWS TOKENS
}

# Creates and manages privileges given to a user on a MySQL server.
resource "mysql_grant" "app" {
  user       = mysql_user.app.user      #db username created for mysql provider
  host       = mysql_user.app.host      #^^ host "%" from above
  database   = var.appointments_db_name #name of DB
  privileges = ["SELECT", "INSERT", "UPDATE", "DELETE"]
}