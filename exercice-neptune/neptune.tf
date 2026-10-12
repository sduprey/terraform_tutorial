# =============================================================================
# neptune.tf — LE FICHIER QUE TU ÉCRIS (exercice 8)
#
# Ce qu'on attend de toi : décrire une base de graphe Neptune protégée.
#   1. Un groupe de sécurité qui n'ouvre que le port de Neptune (8182), et
#      seulement depuis le VPC                     (aws_security_group)
#   2. Un groupe de sous-réseaux sur a et b         (aws_neptune_subnet_group)
#   3. Le cluster                                   (aws_neptune_cluster)
#        - chiffré, authentification IAM activée, sauvegardes gardées 7 jours ;
#        - protégé contre la suppression côté AWS ET côté Terraform ;
#        - avec un snapshot final si on le supprime quand même.
#   4. Deux instances, une d'écriture et une de lecture
#      (aws_neptune_cluster_instance, classe db.t4g.medium)
#
# Vérifie ton code sans AWS :
#   terraform init -backend=false
#   terraform validate
#
# Doc : registry.terraform.io/providers/hashicorp/aws/latest/docs
#       (rubrique « Neptune »)
# =============================================================================

# TODO : à toi de jouer
