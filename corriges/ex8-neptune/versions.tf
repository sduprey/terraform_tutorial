# Point de départ de l'exercice 8. Même configuration que exercice-neptune/.

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
