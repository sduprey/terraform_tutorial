# =============================================================================
# versions.tf — FOURNI, NE PAS MODIFIER
#
# Qui l'a écrit : l'auteur du labo.
#
# Pourquoi : même configuration que exercice-files/, avec un provider en plus :
# archive, qui sait fabriquer un zip à partir d'un dossier. Tu en auras besoin
# à l'étape 7.d, pour reconstruire le paquet de la fonction depuis son code.
#
# Ce dossier a son propre state : l'application Lambda est indépendante du
# réseau des exercices 2 à 5 (voir « Découper en plusieurs states », leçon 4).
#
# Ce qu'on attend de toi : rien. Tout se passe dans imports.tf, puis dans
# generated.tf.
# =============================================================================

terraform {
  required_version = ">= 1.6" # blocs import avec variables et expressions

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
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
