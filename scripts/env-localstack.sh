# shellcheck shell=bash
# =============================================================================
# À SOURCER (pas à exécuter) :   source scripts/env-localstack.sh
#
# Redirige l'AWS CLI (Command Line Interface) et boto3 vers LocalStack.
# Les identifiants "test" sont factices : LocalStack les accepte, AWS les refuse,
# ce qui évite toute fausse manipulation sur un vrai compte.
# Pour Terraform, utilise tflocal à la place de terraform.
# =============================================================================
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_REGION=eu-west-3
export AWS_DEFAULT_REGION=eu-west-3
export AWS_ENDPOINT_URL=http://localhost:4566
unset AWS_PROFILE
echo "Mode LocalStack actif (endpoint $AWS_ENDPOINT_URL, région $AWS_REGION). Utilise tflocal au lieu de terraform."
