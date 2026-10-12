# =============================================================================
# versions.tf — FOURNI, NE PAS MODIFIER
#
# Qui l'a écrit : l'auteur du labo.
#
# Pourquoi : même configuration que les autres exercices. Contrairement aux
# exercices 2 et 7, rien n'existe encore : ici, tu écris une base de graphe
# Neptune de zéro, et tu apprends à la protéger.
#
# Ce qu'on attend de toi : rien. Tout se passe dans neptune.tf.
# =============================================================================

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Projet = "terraform-lab"
    }
  }
}

variable "region" {
  type    = string
  default = "eu-west-3"
}
