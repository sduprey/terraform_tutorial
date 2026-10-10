# =============================================================================
# EXERCICE 2 — Écris un bloc import par ressource réelle.
#
# Pour chaque type, la section « Import » de la documentation du provider
# (registry.terraform.io/providers/hashicorp/aws/latest/docs) donne le format
# de l'id attendu.
#
# Le premier est fait pour toi. Il en reste 7 :
#   - les 2 sous-réseaux                         (aws_subnet)
#   - le groupe de sécurité                      (aws_security_group)
#   - le bucket                                  (aws_s3_bucket)
#   - le versioning du bucket, ressource à part  (aws_s3_bucket_versioning)
#   - le rôle                                    (aws_iam_role)
#   - l'attachement de la politique au rôle      (aws_iam_role_policy_attachment)
#     ⚠ son id a un format composé, va lire la doc.
#
# Ensuite : tflocal init                (terraform init sur un vrai compte)
#           tflocal plan -generate-config-out=generated.tf
# =============================================================================

import {
  to = aws_vpc.main
  id = var.vpc_id
}

# TODO : à toi de jouer
