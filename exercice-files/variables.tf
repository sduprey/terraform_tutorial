# =============================================================================
# variables.tf — FOURNI, NE PAS MODIFIER
#
# Qui l'a écrit : l'auteur du labo.
#
# Pourquoi : les identifiants des objets créés par `make setup` changent à
# chaque exécution (vpc-xxxx, noms horodatés…). Plutôt que de les recopier à la
# main dans imports.tf, on les déclare ici comme variables. Leurs valeurs sont
# dans terraform.tfvars, écrit automatiquement par
# 00-setup/creer-infra-manuelle.sh, et que Terraform charge tout seul.
#
# Ce qu'on attend de toi : rien. Utilise ces variables dans imports.tf
# (par exemple id = var.sg_id).
# =============================================================================

variable "region" { type = string }
variable "vpc_id" { type = string }
variable "subnet_a_id" { type = string }
variable "subnet_b_id" { type = string }
variable "sg_id" { type = string }
variable "bucket_name" { type = string }
variable "role_name" { type = string }
