#!/usr/bin/env bash
# =============================================================================
# Démarre, arrête ou inspecte LocalStack via docker compose.
#
# - Si LOCALSTACK_AUTH_TOKEN est défini (compte gratuit sur localstack.cloud) :
#   image récente localstack/localstack:latest.
# - Sinon : dernière image Community qui ne demande pas de jeton (4.12).
#
# Usage : ./scripts/localstack.sh start|stop|status|logs|reset
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -n "${LOCALSTACK_AUTH_TOKEN:-}" ]; then
  export LOCALSTACK_IMAGE="${LOCALSTACK_IMAGE:-localstack/localstack:latest}"
else
  export LOCALSTACK_IMAGE="${LOCALSTACK_IMAGE:-localstack/localstack:4.12}"
fi

attendre() {
  printf "Attente de LocalStack"
  for _ in $(seq 1 60); do
    if curl -sf http://localhost:4566/_localstack/health >/dev/null 2>&1; then
      echo " : prêt."
      return 0
    fi
    printf "."; sleep 2
  done
  echo; echo "LocalStack ne répond pas. Regarde : ./scripts/localstack.sh logs"; exit 1
}

case "${1:-}" in
  start)
    docker info >/dev/null 2>&1 || { echo "Docker ne tourne pas (ouvre OrbStack ou Docker Desktop)."; exit 1; }
    echo "Image : $LOCALSTACK_IMAGE"
    docker compose up -d
    attendre
    "$0" status
    ;;
  stop)   docker compose down ;;
  reset)  docker compose down -v && rm -rf .localstack-data && echo "LocalStack remis à zéro." ;;
  logs)   docker compose logs -f localstack ;;
  status)
    curl -s http://localhost:4566/_localstack/health | python3 -c '
import json, sys
s = json.load(sys.stdin)["services"]
for nom in ("ec2", "s3", "iam", "sts"):
    print(f"  {nom:4s} : {s.get(nom, \"absent\")}")
' ;;
  *) echo "Usage : $0 start|stop|status|logs|reset"; exit 1 ;;
esac
