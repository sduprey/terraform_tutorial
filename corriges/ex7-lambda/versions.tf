# Point de départ de l'exercice 7. Même configuration que exercice-lambda/.

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
