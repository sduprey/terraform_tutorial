# =============================================================================
# variables.tf — FOURNI, NE PAS MODIFIER
#
# Qui l'a écrit : l'auteur du labo.
#
# Pourquoi : les identifiants des objets créés par `make setup-lambda` changent
# à chaque exécution (noms horodatés, URL de la file, UUID du déclencheur).
# Leurs valeurs sont dans terraform.tfvars, écrit automatiquement par
# 00-setup/creer-lambda-manuelle.sh, et que Terraform charge tout seul.
#
# Ce qu'on attend de toi : rien. Utilise ces variables dans imports.tf
# (par exemple id = var.function_name).
# =============================================================================

variable "region" { type = string }
variable "role_name" { type = string }
variable "queue_name" { type = string }
variable "queue_url" { type = string }
variable "function_name" { type = string }
variable "mapping_uuid" { type = string }
