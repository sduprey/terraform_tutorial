# =============================================================================
# imports.tf — LE FICHIER QUE TU COMPLÈTES (exercice 2)
#
# Qui l'a écrit : l'auteur du labo, à moitié. Le premier bloc est donné en
# exemple, les sept autres sont à toi.
#
# Pourquoi : `make setup` (exercice 1) a créé huit objets dans LocalStack, mais
# Terraform ne les connaît pas. Un bloc import dit à Terraform « cet objet
# existant (id) correspond à telle ressource de mon code (to) ». Sans lui,
# Terraform créerait des doublons au lieu de reprendre l'existant.
#
# Ce qu'on attend de toi :
#   1. Écrire un bloc import par objet restant (7) :
#        - les 2 sous-réseaux                         (aws_subnet)
#        - le groupe de sécurité                      (aws_security_group)
#        - le bucket                                  (aws_s3_bucket)
#        - le versioning du bucket, ressource à part  (aws_s3_bucket_versioning)
#        - le rôle                                    (aws_iam_role)
#        - l'attachement de la politique au rôle      (aws_iam_role_policy_attachment)
#          ⚠ son id a un format composé, va lire la doc.
#      Les ids sont dans terraform.tfvars, accessibles via var.xxx
#      (voir variables.tf). Le format attendu pour chaque type est dans la
#      section « Import » de la doc du provider :
#      registry.terraform.io/providers/hashicorp/aws/latest/docs
#   2. Faire générer le code correspondant :
#        tflocal init
#        tflocal plan -generate-config-out=generated.tf
#   3. Nettoyer generated.tf jusqu'à ce que `tflocal plan` n'annonce plus
#      aucun changement (voir EXERCICES.md, exercice 2).
#
# (Sur un vrai compte AWS, remplace tflocal par terraform.)
# =============================================================================

import {
  to = aws_vpc.main
  id = var.vpc_id
}

# TODO : à toi de jouer
