#!/usr/bin/env bash
# =============================================================================
# Installe tout ce qu'il faut sur macOS pour le laboratoire :
#   - Terraform (dépôt officiel HashiCorp)
#   - AWS CLI (Amazon Web Services Command Line Interface)
#   - un moteur Docker (OrbStack, plus léger que Docker Desktop sur Mac),
#     sauf si Docker est déjà présent
#   - pipx puis tflocal (paquet terraform-local), la surcouche qui redirige
#     Terraform vers LocalStack
#   - Ollama, pour faire tourner un modèle de langage en local (agent, leçon 5)
#   - un environnement virtuel Python (.venv) avec boto3, pytest, Strands Agents
#     et le SDK (Software Development Kit) bedrock-agentcore
#
# Idempotent : tu peux le relancer sans risque.
# Usage : ./scripts/install-mac.sh
# =============================================================================
set -euo pipefail

ok()   { printf "\033[32m✔\033[0m %s\n" "$*"; }
info() { printf "\033[34m→\033[0m %s\n" "$*"; }
fail() { printf "\033[31m✘\033[0m %s\n" "$*"; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "Ce script est prévu pour macOS."

if ! command -v brew >/dev/null 2>&1; then
  fail "Homebrew est absent. Installe-le d'abord (une ligne, sur https://brew.sh), puis relance ce script."
fi
ok "Homebrew $(brew --version | head -1 | awk '{print $2}')"

info "Terraform, AWS CLI, pipx, jq, Python"
brew tap hashicorp/tap >/dev/null
brew install hashicorp/tap/terraform awscli pipx jq python@3.12 >/dev/null
ok "$(terraform version | head -1)"
ok "$(aws --version 2>&1 | awk '{print $1}')"

if command -v docker >/dev/null 2>&1; then
  ok "Docker déjà présent : $(docker --version)"
else
  info "Aucun Docker trouvé : installation d'OrbStack"
  brew install --cask orbstack >/dev/null
  ok "OrbStack installé. Ouvre-le une première fois (Applications > OrbStack) pour démarrer le moteur Docker."
fi

info "Ollama"
brew install ollama >/dev/null
brew services start ollama >/dev/null 2>&1 || true
ok "Ollama installé et démarré en tâche de fond (modèle à télécharger : make ollama-pull)"

info "tflocal (terraform-local)"
pipx ensurepath >/dev/null 2>&1 || true
pipx install terraform-local >/dev/null 2>&1 || pipx upgrade terraform-local >/dev/null 2>&1 || true
export PATH="$HOME/.local/bin:$PATH"
command -v tflocal >/dev/null 2>&1 && ok "tflocal installé" || fail "tflocal introuvable dans le PATH (Ouvre un nouveau terminal puis relance.)"

info "Environnement Python du projet (.venv)"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$(brew --prefix python@3.12)/bin/python3.12" -m venv "$ROOT/.venv"
"$ROOT/.venv/bin/pip" install --quiet --upgrade pip boto3 pytest
"$ROOT/.venv/bin/pip" install --quiet -r "$ROOT/agent-local/requirements.txt"
ok ".venv prêt (boto3, pytest, strands-agents, bedrock-agentcore)"

echo
ok "Installation terminée. Étape suivante : make start"
