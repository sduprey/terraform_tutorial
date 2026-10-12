#!/usr/bin/env bash
# =============================================================================
# Exercice 7 — Créer "à la main" (via l'AWS CLI, Amazon Web Services Command
# Line Interface) une petite application Lambda, comme si une autre équipe
# l'avait déployée depuis son poste. C'est ce que tu devras ensuite extraire
# avec Terraform.
#
# Ressources créées (toutes taguées Projet=terraform-lab) :
#   - 1 rôle IAM (Identity and Access Management) d'exécution, assumable par
#     Lambda, avec la politique gérée AWSLambdaSQSQueueExecutionRole
#   - 1 file SQS (Simple Queue Service) lab-jobs
#   - 1 groupe de journaux CloudWatch /aws/lambda/<fonction>, rétention 14 jours
#   - 1 fonction Lambda Python, sa version publiée 1 et un alias live -> 1
#   - 1 déclencheur (event source mapping) : la file SQS appelle l'alias live
#
# Le code de la fonction est écrit dans un dossier temporaire, zippé, envoyé à
# AWS, puis SUPPRIMÉ : comme chez un vrai client, il n'existe plus que dans AWS.
#
# Coût : quasi nul (aucun message n'est envoyé dans la file).
#
# Usage : AWS_REGION=eu-west-3 ./creer-lambda-manuelle.sh
# =============================================================================
set -euo pipefail

REGION="${AWS_REGION:-eu-west-3}"
export AWS_REGION="$REGION"
SUFFIX="$(date +%s)"
OUT_DIR="$(cd "$(dirname "$0")/.." && pwd)/exercice-lambda"

if [ -n "${AWS_ENDPOINT_URL:-}" ]; then
  echo ">> Mode LocalStack : $AWS_ENDPOINT_URL"
else
  echo ">> ATTENTION : aucun AWS_ENDPOINT_URL, tu vises un VRAI compte AWS."
  read -r -p "   Continuer ? (oui/non) " rep
  [ "$rep" = "oui" ] || exit 1
fi
echo ">> Compte : $(aws sts get-caller-identity --query Account --output text) — région : $REGION"

echo ">> Rôle IAM d'exécution"
ROLE_NAME="lab-lambda-role-${SUFFIX}"
ROLE_ARN=$(aws iam create-role --role-name "$ROLE_NAME" \
  --description "Lab Terraform - role d'execution Lambda" \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }' \
  --tags Key=Name,Value=lab-lambda-role Key=Projet,Value=terraform-lab \
  --query Role.Arn --output text)
aws iam attach-role-policy --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole

echo ">> File SQS"
QUEUE_NAME="lab-jobs-${SUFFIX}"
# Le délai de visibilité doit être >= au timeout de la fonction (30 s).
QUEUE_URL=$(aws sqs create-queue --queue-name "$QUEUE_NAME" \
  --attributes VisibilityTimeout=60 \
  --tags Name=lab-jobs,Projet=terraform-lab \
  --query QueueUrl --output text)
QUEUE_ARN=$(aws sqs get-queue-attributes --queue-url "$QUEUE_URL" \
  --attribute-names QueueArn --query Attributes.QueueArn --output text)

echo ">> Groupe de journaux"
FUNCTION_NAME="lab-worker-${SUFFIX}"
aws logs create-log-group --log-group-name "/aws/lambda/$FUNCTION_NAME" \
  --tags Name=lab-worker-logs,Projet=terraform-lab
aws logs put-retention-policy --log-group-name "/aws/lambda/$FUNCTION_NAME" \
  --retention-in-days 14

echo ">> Code de la fonction (dossier temporaire)"
TMP="$(mktemp -d)"
cat > "$TMP/app.py" <<'PY'
"""Traite les messages de la file lab-jobs, un par un."""
import logging
import os

log = logging.getLogger()
log.setLevel(os.environ.get("NIVEAU_LOG", "INFO"))


def handler(event, context):
    messages = event.get("Records", [])
    for message in messages:
        log.info("Message reçu : %s", message["body"])
    return {"traites": len(messages)}
PY
(cd "$TMP" && python3 -m zipfile -c code.zip app.py)

# Sur un vrai compte, un rôle tout juste créé met quelques secondes à être
# utilisable par Lambda.
[ -n "${AWS_ENDPOINT_URL:-}" ] || sleep 10

echo ">> Fonction Lambda"
aws lambda create-function --function-name "$FUNCTION_NAME" \
  --description "Lab Terraform - traite les messages de la file lab-jobs" \
  --runtime python3.12 --handler app.handler --role "$ROLE_ARN" \
  --timeout 30 --memory-size 256 \
  --environment 'Variables={NIVEAU_LOG=INFO}' \
  --zip-file "fileb://$TMP/code.zip" \
  --tags Name=lab-worker,Projet=terraform-lab > /dev/null
aws lambda wait function-active-v2 --function-name "$FUNCTION_NAME"
rm -rf "$TMP" # le code n'existe plus que dans AWS

echo ">> Version 1 et alias live"
aws lambda publish-version --function-name "$FUNCTION_NAME" > /dev/null
aws lambda create-alias --function-name "$FUNCTION_NAME" --name live \
  --function-version 1 > /dev/null

echo ">> Déclencheur SQS -> alias live"
MAPPING_UUID=$(aws lambda create-event-source-mapping \
  --function-name "$FUNCTION_NAME:live" --event-source-arn "$QUEUE_ARN" \
  --batch-size 5 --query UUID --output text)

# Comme pour l'exercice 2, les identifiants vont dans terraform.tfvars.
cat > "$OUT_DIR/terraform.tfvars" <<EOF
# Écrit automatiquement par \`make setup-lambda\` (00-setup/creer-lambda-manuelle.sh).
# Ne pas modifier : ce sont les identifiants des objets créés dans LocalStack.
# Terraform charge ce fichier tout seul et remplit les variables de variables.tf.
region        = "$REGION"
role_name     = "$ROLE_NAME"
queue_name    = "$QUEUE_NAME"
queue_url     = "$QUEUE_URL"
function_name = "$FUNCTION_NAME"
mapping_uuid  = "$MAPPING_UUID"
EOF

cp "$OUT_DIR/terraform.tfvars" "$(dirname "$0")/ids-lambda.tfvars"

echo
echo "Terminé. Identifiants écrits dans exercice-lambda/terraform.tfvars :"
cat "$OUT_DIR/terraform.tfvars"
