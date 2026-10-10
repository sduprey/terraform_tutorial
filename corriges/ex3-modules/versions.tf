# Point de départ de l'exercice 2. Ne modifie pas ce fichier : tout se passe
# dans imports.tf, puis dans le code généré.

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
