#!/usr/bin/env bash
# =============================================================================
# Filet de sécurité : supprime l'application Lambda de l'exercice 7 avec l'AWS
# CLI (Amazon Web Services Command Line Interface), au cas où tu n'aurais pas
# fini l'exercice (terraform destroy).
# Lit les identifiants dans 00-setup/ids-lambda.tfvars.
# =============================================================================
set -uo pipefail

IDS="$(dirname "$0")/ids-lambda.tfvars"
[ -f "$IDS" ] || { echo "Fichier $IDS introuvable."; exit 1; }

val() { grep "^$1 " "$IDS" | sed -E 's/.*= *"(.*)"/\1/'; }

AWS_REGION="$(val region)"
export AWS_REGION
ROLE_NAME=$(val role_name); QUEUE_URL=$(val queue_url)
FUNCTION_NAME=$(val function_name); MAPPING_UUID=$(val mapping_uuid)

echo ">> Déclencheur $MAPPING_UUID"
aws lambda delete-event-source-mapping --uuid "$MAPPING_UUID" > /dev/null 2>&1

echo ">> Fonction $FUNCTION_NAME (alias et versions compris)"
aws lambda delete-function --function-name "$FUNCTION_NAME" 2>/dev/null
aws logs delete-log-group --log-group-name "/aws/lambda/$FUNCTION_NAME" 2>/dev/null

echo ">> File SQS (Simple Queue Service)"
aws sqs delete-queue --queue-url "$QUEUE_URL" 2>/dev/null

echo ">> Rôle IAM (Identity and Access Management) $ROLE_NAME"
aws iam detach-role-policy --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole 2>/dev/null
aws iam delete-role --role-name "$ROLE_NAME" 2>/dev/null

echo "Terminé (les erreurs « introuvable » sont normales si terraform destroy est déjà passé)."
