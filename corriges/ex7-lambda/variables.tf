# Les valeurs sont dans terraform.tfvars, écrit par 00-setup/creer-lambda-manuelle.sh.

variable "region" { type = string }
variable "role_name" { type = string }
variable "queue_name" { type = string }
variable "queue_url" { type = string }
variable "function_name" { type = string }
variable "mapping_uuid" { type = string }
