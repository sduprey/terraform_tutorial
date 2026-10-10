# =============================================================================
# Corrigé de l'exercice 3 — le même compte, restructuré en deux modules.
# Critère de réussite : le plan n'affiche QUE des déplacements (moved), aucun
# ajout, aucune modification, aucune destruction.
# =============================================================================

module "network" {
  source = "./modules/network"

  name       = "lab"
  cidr_block = "10.42.0.0/16"

  subnets = {
    a = { cidr_block = "10.42.1.0/24", availability_zone = "${var.region}a" }
    b = { cidr_block = "10.42.2.0/24", availability_zone = "${var.region}b" }
  }
}

module "app" {
  source = "./modules/app"

  bucket_name = var.bucket_name
  role_name   = var.role_name
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "subnet_ids" {
  value = module.network.subnet_ids
}

output "bucket_arn" {
  value = module.app.bucket_arn
}
