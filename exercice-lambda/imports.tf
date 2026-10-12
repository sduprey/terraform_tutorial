# =============================================================================
# imports.tf — LE FICHIER QUE TU COMPLÈTES (exercice 7)
#
# Qui l'a écrit : l'auteur du labo, à moitié. Le premier bloc est donné en
# exemple, les six autres sont à toi.
#
# Pourquoi : `make setup-lambda` a créé sept objets dans LocalStack, mais
# Terraform ne les connaît pas.
#
# Ce qu'on attend de toi :
#   1. Écrire un bloc import par objet restant (6) :
#        - l'attachement de la politique au rôle  (aws_iam_role_policy_attachment)
#          ⚠ la politique est rangée sous service-role/ : regarde son ARN exact
#            avec aws iam list-attached-role-policies
#        - la file                                (aws_sqs_queue)
#          ⚠ son id n'est pas son nom
#        - le groupe de journaux                  (aws_cloudwatch_log_group)
#        - la fonction                            (aws_lambda_function)
#        - l'alias live                           (aws_lambda_alias)
#        - le déclencheur SQS                     (aws_lambda_event_source_mapping)
#      Le format attendu pour chaque type est dans la section « Import » de la
#      doc du provider : registry.terraform.io/providers/hashicorp/aws/latest/docs
#   2. Faire générer le code correspondant :
#        tflocal init
#        tflocal plan -generate-config-out=generated.tf
#   3. Récupérer le code de la fonction, puis nettoyer generated.tf
#      (voir EXERCICES.md, exercice 7).
#
# (Sur un vrai compte AWS, remplace tflocal par terraform.)
# =============================================================================

import {
  to = aws_iam_role.lambda
  id = var.role_name
}

# TODO : à toi de jouer
