# =============================================================================
# reseau.tf — FOURNI, NE PAS MODIFIER
#
# Qui l'a écrit : l'auteur du labo.
#
# Pourquoi : Neptune ne vit que dans un VPC (Virtual Private Cloud), sur au
# moins deux sous-réseaux de zones différentes. Ce réseau minimal est fourni
# pour que tu te concentres sur la base.
#
# Ce qu'on attend de toi : rien. Utilise ces ressources dans neptune.tf
# (par exemple aws_subnet.a.id).
# =============================================================================

resource "aws_vpc" "graphe" {
  cidr_block = "10.43.0.0/16"

  tags = { Name = "lab-graphe-vpc" }
}

resource "aws_subnet" "a" {
  vpc_id            = aws_vpc.graphe.id
  cidr_block        = "10.43.1.0/24"
  availability_zone = "${var.region}a"

  tags = { Name = "lab-graphe-subnet-a" }
}

resource "aws_subnet" "b" {
  vpc_id            = aws_vpc.graphe.id
  cidr_block        = "10.43.2.0/24"
  availability_zone = "${var.region}b"

  tags = { Name = "lab-graphe-subnet-b" }
}
