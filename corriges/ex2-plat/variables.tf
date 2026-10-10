# Les valeurs sont dans terraform.tfvars, écrit par 00-setup/creer-infra-manuelle.sh.

variable "region" { type = string }
variable "vpc_id" { type = string }
variable "subnet_a_id" { type = string }
variable "subnet_b_id" { type = string }
variable "sg_id" { type = string }
variable "bucket_name" { type = string }
variable "role_name" { type = string }
