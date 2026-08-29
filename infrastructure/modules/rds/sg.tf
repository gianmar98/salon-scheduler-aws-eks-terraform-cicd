# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

# Whichever machine runs `apply` becomes the allowed client. If CI ever applies this,
# the rule silently repoints at the build agent.
data "http" "myip" {
  url = "https://checkip.amazonaws.com"
}

resource "aws_security_group" "rds_sg" {
  name        = "${var.appointments_db_identifier}-sg"
  description = "Client access to the ${var.appointments_db_identifier} DB instance"
  vpc_id      = var.appointments_db_vpc_id

  tags = {
    Name = "${var.appointments_db_identifier}-sg"
  }
}

# No egress rule on purpose: the instance never opens outbound connections.
resource "aws_vpc_security_group_ingress_rule" "mysql_from_client" {
  security_group_id = aws_security_group.rds_sg.id
  cidr_ipv4         = "${chomp(data.http.myip.response_body)}/32"
  from_port         = var.appointments_db_port
  to_port           = var.appointments_db_port
  ip_protocol       = "tcp"
  description       = "Inbound access from local IP"
  tags = {
    Name = "Local IP access"
  }
}