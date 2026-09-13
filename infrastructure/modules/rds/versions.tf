# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: Apache-2.0

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.4"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.6"
    }
    mysql = {
      source  = "petoju/mysql" #Teaches terraform to talk to MySQL
      version = "~> 3.0"
    }
  }
}