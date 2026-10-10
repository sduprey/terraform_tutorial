#!/usr/bin/env bash
# =============================================================================
# Filet de sécurité : supprime l'infrastructure du laboratoire avec l'AWS CLI
# (Amazon Web Services Command Line Interface), au cas où tu n'aurais pas fini
# l'exercice 5 (terraform destroy).
# Lit les identifiants dans 00-setup/ids-crees.tfvars.
# =============================================================================
set -uo pipefail

IDS="$(dirname "$0")/ids-crees.tfvars"
[ -f "$IDS" ] || { echo "Fichier $IDS introuvable."; exit 1; }

val() { grep "^$1 " "$IDS" | sed -E 's/.*= *"(.*)"/\1/'; }

AWS_REGION="$(val region)"
export AWS_REGION
VPC_ID=$(val vpc_id); SUBNET_A_ID=$(val subnet_a_id); SUBNET_B_ID=$(val subnet_b_id)
SG_ID=$(val sg_id); BUCKET_NAME=$(val bucket_name); ROLE_NAME=$(val role_name)

echo ">> Rôle IAM (Identity and Access Management) $ROLE_NAME"
aws iam detach-role-policy --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess 2>/dev/null
aws iam delete-role --role-name "$ROLE_NAME" 2>/dev/null

echo ">> Bucket S3 (Simple Storage Service) $BUCKET_NAME (vidage des versions puis suppression)"
python3 - "$BUCKET_NAME" <<'PY' 2>/dev/null || aws s3 rb "s3://$BUCKET_NAME" --force
import sys, boto3
b = boto3.resource("s3").Bucket(sys.argv[1])
b.object_versions.delete()
b.delete()
PY

echo ">> Groupe de sécurité, sous-réseaux, VPC (Virtual Private Cloud)"
aws ec2 delete-security-group --group-id "$SG_ID" 2>/dev/null
aws ec2 delete-subnet --subnet-id "$SUBNET_A_ID" 2>/dev/null
aws ec2 delete-subnet --subnet-id "$SUBNET_B_ID" 2>/dev/null
aws ec2 delete-vpc --vpc-id "$VPC_ID" 2>/dev/null

echo "Terminé (les erreurs « introuvable » sont normales si terraform destroy est déjà passé)."
