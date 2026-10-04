# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

# Resource creates and manages a user on a MySQL server
resource "mysql_user" "app" {
  user        = var.appointments_db_iam_username
  host        = "%"                       #"%" = connect from anywhere.
  auth_plugin = "AWSAuthenticationPlugin" #no password for login so it accepts AWS TOKENS

  # The provider connects from this machine's IP. Without this, destroy can delete that
  # rule first and then time out trying to drop the user. The grant inherits the order.
  depends_on = [aws_vpc_security_group_ingress_rule.mysql_from_client]
}

# Creates and manages privileges given to a user on a MySQL server.
resource "mysql_grant" "app" {
  user       = mysql_user.app.user      #db username created for mysql provider
  host       = mysql_user.app.host      #^^ host "%" from above
  database   = var.appointments_db_name #name of DB
  privileges = ["SELECT", "INSERT", "UPDATE", "DELETE"]
}