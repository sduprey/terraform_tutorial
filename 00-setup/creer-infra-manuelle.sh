#!/usr/bin/env bash
# =============================================================================
# Exercice 1 — Créer "à la main" (via l'AWS CLI, Amazon Web Services Command
# Line Interface) une petite infrastructure, comme si elle avait été cliquée
# dans la console par quelqu'un d'autre. C'est ce que tu devras ensuite
# extraire avec Terraform.
#
# Ressources créées (toutes taguées Projet=terraform-lab) :
#   - 1 VPC (Virtual Private Cloud, réseau privé virtuel) 10.42.0.0/16
#   - 2 sous-réseaux (subnets) dans deux AZ (Availability Zones, zones de disponibilité)
#   - 1 groupe de sécurité (security group) qui autorise HTTPS (port 443) en entrée
#   - 1 bucket S3 (Simple Storage Service) versionné
#   - 1 rôle IAM (Identity and Access Management) assumable par EC2
#     (Elastic Compute Cloud), avec la politique gérée AmazonS3ReadOnlyAccess
#
# Coût : quasi nul (aucune instance, aucune passerelle NAT, Network Address
# Translation). Pense quand même à tout détruire à la fin.
#
# Usage : AWS_REGION=eu-west-3 ./creer-infra-manuelle.sh
# =============================================================================
set -euo pipefail

REGION="${AWS_REGION:-eu-west-3}"
export AWS_REGION="$REGION"
SUFFIX="$(date +%s)"
OUT_DIR="$(cd "$(dirname "$0")/.." && pwd)/01-exercice"

tags() { # tags <type de ressource> <nom>
  echo "ResourceType=$1,Tags=[{Key=Name,Value=$2},{Key=Projet,Value=terraform-lab}]"
}

if [ -n "${AWS_ENDPOINT_URL:-}" ]; then
  echo ">> Mode LocalStack : $AWS_ENDPOINT_URL"
else
  echo ">> ATTENTION : aucun AWS_ENDPOINT_URL, tu vises un VRAI compte AWS."
  read -r -p "   Continuer ? (oui/non) " rep
  [ "$rep" = "oui" ] || exit 1
fi
echo ">> Compte : $(aws sts get-caller-identity --query Account --output text) — région : $REGION"

echo ">> VPC"
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.42.0.0/16 \
  --tag-specifications "$(tags vpc lab-vpc)" \
  --query Vpc.VpcId --output text)
aws ec2 wait vpc-available --vpc-ids "$VPC_ID"
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames '{"Value":true}'

echo ">> Sous-réseaux"
SUBNET_A_ID=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.42.1.0/24 \
  --availability-zone "${REGION}a" --tag-specifications "$(tags subnet lab-subnet-a)" \
  --query Subnet.SubnetId --output text)
SUBNET_B_ID=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.42.2.0/24 \
  --availability-zone "${REGION}b" --tag-specifications "$(tags subnet lab-subnet-b)" \
  --query Subnet.SubnetId --output text)

echo ">> Groupe de sécurité"
SG_ID=$(aws ec2 create-security-group --group-name lab-web \
  --description "Lab Terraform - HTTPS entrant" --vpc-id "$VPC_ID" \
  --tag-specifications "$(tags security-group lab-web)" \
  --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --ip-permissions 'IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges=[{CidrIp=0.0.0.0/0,Description="HTTPS public"}]' \
  > /dev/null

echo ">> Bucket S3"
BUCKET_NAME="lab-tf-${SUFFIX}"
if [ "$REGION" = "us-east-1" ]; then
  aws s3api create-bucket --bucket "$BUCKET_NAME" > /dev/null
else
  aws s3api create-bucket --bucket "$BUCKET_NAME" \
    --create-bucket-configuration LocationConstraint="$REGION" > /dev/null
fi
aws s3api put-bucket-tagging --bucket "$BUCKET_NAME" \
  --tagging 'TagSet=[{Key=Name,Value=lab-bucket},{Key=Projet,Value=terraform-lab}]'
aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled

echo ">> Rôle IAM"
ROLE_NAME="lab-app-role-${SUFFIX}"
aws iam create-role --role-name "$ROLE_NAME" \
  --description "Lab Terraform - role applicatif" \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }' \
  --tags Key=Name,Value=lab-app-role Key=Projet,Value=terraform-lab > /dev/null
aws iam attach-role-policy --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

# Les identifiants sont écrits dans terraform.tfvars : les blocs import de
# l'exercice les lisent via des variables (possible depuis Terraform 1.6).
cat > "$OUT_DIR/terraform.tfvars" <<EOF
region      = "$REGION"
vpc_id      = "$VPC_ID"
subnet_a_id = "$SUBNET_A_ID"
subnet_b_id = "$SUBNET_B_ID"
sg_id       = "$SG_ID"
bucket_name = "$BUCKET_NAME"
role_name   = "$ROLE_NAME"
EOF

cp "$OUT_DIR/terraform.tfvars" "$(dirname "$0")/ids-crees.tfvars"

echo
echo "Terminé. Identifiants écrits dans 01-exercice/terraform.tfvars :"
cat "$OUT_DIR/terraform.tfvars"
