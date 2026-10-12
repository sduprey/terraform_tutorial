# =============================================================================
# Corrigé de l'exercice 8 — une base de graphe Neptune protégée.
#
# Les choix à retenir :
#   1. Deux protections contre la suppression, qui ne se remplacent pas :
#      prevent_destroy (Terraform refuse le plan) et deletion_protection (AWS
#      refuse l'appel, même depuis la console).
#   2. skip_final_snapshot = false : si la base est quand même supprimée, AWS
#      en garde une copie.
#   3. storage_encrypted fixé dès la création : le changer plus tard force le
#      remplacement du cluster, donc la perte des données.
#   4. Les données du graphe ne passent jamais par Terraform : elles se chargent
#      avec le bulk loader de Neptune ou par des requêtes Gremlin, openCypher
#      ou SPARQL.
# =============================================================================

resource "aws_security_group" "neptune" {
  name        = "lab-neptune"
  description = "Lab Terraform - acces Neptune depuis le VPC"
  vpc_id      = aws_vpc.graphe.id

  ingress {
    description = "Neptune (Gremlin, openCypher, SPARQL)"
    protocol    = "tcp"
    from_port   = 8182
    to_port     = 8182
    cidr_blocks = [aws_vpc.graphe.cidr_block]
  }

  tags = { Name = "lab-neptune" }
}

resource "aws_neptune_subnet_group" "graphe" {
  name       = "lab-graphe"
  subnet_ids = [aws_subnet.a.id, aws_subnet.b.id]

  tags = { Name = "lab-graphe" }
}

resource "aws_neptune_cluster" "graphe" {
  cluster_identifier                  = "lab-graphe"
  engine                              = "neptune"
  neptune_subnet_group_name           = aws_neptune_subnet_group.graphe.name
  vpc_security_group_ids              = [aws_security_group.neptune.id]
  storage_encrypted                   = true
  iam_database_authentication_enabled = true
  backup_retention_period             = 7
  deletion_protection                 = true
  skip_final_snapshot                 = false
  final_snapshot_identifier           = "lab-graphe-final"

  tags = { Name = "lab-graphe" }

  lifecycle {
    prevent_destroy = true
  }
}

# count suffit ici : les deux instances sont interchangeables. La première
# créée devient l'instance d'écriture ; en cas de panne, Neptune promeut
# l'autre.
resource "aws_neptune_cluster_instance" "graphe" {
  count              = 2
  identifier         = "lab-graphe-${count.index}"
  cluster_identifier = aws_neptune_cluster.graphe.id
  instance_class     = "db.t4g.medium"

  tags = { Name = "lab-graphe-${count.index}" }
}
