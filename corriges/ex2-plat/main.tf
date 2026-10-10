# =============================================================================
# Corrigé de l'exercice 2 — ce que devient generated.tf après nettoyage.
#
# Ce qui a été fait par rapport au code généré :
#   1. Suppression des attributs à leur valeur par défaut (force_destroy = false,
#      instance_tenancy = "default", etc.) et des attributs calculés.
#   2. Remplacement des IDs (identifiants) en dur par des références :
#      vpc_id = aws_vpc.main.id au lieu de "vpc-0abc...". C'est ce qui crée le
#      graphe de dépendances.
#   3. Suppression du tag Projet sur chaque ressource : default_tags s'en charge.
#   4. Politique d'approbation (trust policy) réécrite avec jsonencode() au lieu
#      d'une chaîne JSON (JavaScript Object Notation) échappée illisible.
#   5. Suppression de managed_policy_arns et inline_policy sur le rôle : ces
#      arguments entrent en conflit avec aws_iam_role_policy_attachment.
#   6. lifecycle prevent_destroy sur le bucket (donnée = ressource critique).
#
# Critère de réussite : terraform plan affiche
#   "Plan: 8 to import, 0 to add, 0 to change, 0 to destroy."
# =============================================================================

# --- Réseau -------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = "10.42.0.0/16"
  enable_dns_hostnames = true

  tags = { Name = "lab-vpc" }
}

resource "aws_subnet" "a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.42.1.0/24"
  availability_zone = "${var.region}a"

  tags = { Name = "lab-subnet-a" }
}

resource "aws_subnet" "b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.42.2.0/24"
  availability_zone = "${var.region}b"

  tags = { Name = "lab-subnet-b" }
}

resource "aws_security_group" "web" {
  name        = "lab-web"
  description = "Lab Terraform - HTTPS entrant"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS public"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Règle de sortie créée automatiquement par AWS : si tu ne la déclares pas,
  # Terraform voudra la supprimer (les règles inline sont exhaustives).
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "lab-web" }
}

# --- Données ------------------------------------------------------------------

resource "aws_s3_bucket" "data" {
  bucket = var.bucket_name

  tags = { Name = "lab-bucket" }

  lifecycle {
    prevent_destroy = true # à retirer avant l'exercice 5 (destroy)
  }
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id

  versioning_configuration {
    status = "Enabled"
  }
}

# --- Identités ----------------------------------------------------------------

resource "aws_iam_role" "app" {
  name        = var.role_name
  description = "Lab Terraform - role applicatif"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "lab-app-role" }
}

resource "aws_iam_role_policy_attachment" "app_s3_read" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}
