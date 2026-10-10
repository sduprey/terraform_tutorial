# =============================================================================
# versions.tf — FOURNI, NE PAS MODIFIER
#
# Qui l'a écrit : l'auteur du labo.
#
# Pourquoi : avant de pouvoir importer quoi que ce soit, Terraform doit savoir
# quelle version utiliser, quel provider (le « pilote » AWS) télécharger et
# dans quelle région travailler. C'est la configuration minimale commune à tous
# les exercices.
#
# Ce qu'on attend de toi : rien. Tout se passe dans imports.tf, puis dans
# generated.tf (le code que Terraform générera pour toi).
# =============================================================================

terraform {
  required_version = ">= 1.6" # blocs import avec variables

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Sur une vraie mission, le state irait dans un backend distant :
  # backend "s3" {
  #   bucket       = "monclient-tfstate"
  #   key          = "extraction/terraform.tfstate"
  #   region       = "eu-west-3"
  #   encrypt      = true
  #   use_lockfile = true
  # }
}

provider "aws" {
  region = var.region

  # Tags appliqués automatiquement à toutes les ressources gérées.
  # Réflexe d'expert : cela évite de répéter Projet = "terraform-lab" partout.
  default_tags {
    tags = {
      Projet = "terraform-lab"
    }
  }
}
