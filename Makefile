# Raccourcis du laboratoire. `make help` pour la liste.
SHELL := /bin/bash

# Toutes les cibles qui touchent à "AWS" visent LocalStack, jamais un vrai compte.
LS_ENV := env -u AWS_PROFILE AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_REGION=eu-west-3 \
          AWS_DEFAULT_REGION=eu-west-3 AWS_ENDPOINT_URL=http://localhost:4566
PY := .venv/bin/python
MODELE ?= llama3.2
Q ?= Quelles ressources sont dans le state de exercice-files ?

.PHONY: help install start stop status reset setup destroy-manual setup-lambda destroy-lambda \n        test validate clean \
        ollama-pull agent-run agent-ping agent-ask

help: ## Affiche cette aide
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

install: ## Installe les outils sur macOS
	./scripts/install-mac.sh

start: ## Démarre LocalStack
	./scripts/localstack.sh start

stop: ## Arrête LocalStack
	./scripts/localstack.sh stop

status: ## État des services LocalStack
	./scripts/localstack.sh status

reset: ## Remet LocalStack à zéro (efface tout)
	./scripts/localstack.sh reset

setup: ## Exercice 1 : crée l'infrastructure "à la main" dans LocalStack
	$(LS_ENV) ./00-setup/creer-infra-manuelle.sh

destroy-manual: ## Supprime l'infrastructure du labo sans Terraform
	$(LS_ENV) PATH=".venv/bin:$$PATH" ./00-setup/detruire-infra-manuelle.sh

setup-lambda: ## Exercice 7 : crée l'application Lambda "à la main" dans LocalStack
	$(LS_ENV) ./00-setup/creer-lambda-manuelle.sh

destroy-lambda: ## Supprime l'application Lambda de l'exercice 7 sans Terraform
	$(LS_ENV) ./00-setup/detruire-lambda-manuelle.sh

test: ## Tests du générateur de blocs import
	$(PY) -m pytest -q tests

validate: ## fmt + validate sur l'exercice et les corrigés (sans backend)
	terraform fmt -check -recursive
	@for d in exercice-files exercice-lambda exercice-neptune corriges/ex2-plat corriges/ex3-modules \
	         corriges/ex7-lambda corriges/ex8-neptune; do \
	  echo "== $$d"; (cd $$d && terraform init -backend=false -input=false >/dev/null && terraform validate) || exit 1; \
	done

ollama-pull: ## Télécharge le modèle de l'agent (MODELE=llama3.2 par défaut)
	ollama pull $(MODELE)

agent-run: ## Lance l'agent local sur le port 8080 (contrat AgentCore Runtime)
	AGENT_MODELE=$(MODELE) $(PY) agent-local/agent.py

agent-ping: ## Contrôle de santé de l'agent
	curl -s http://localhost:8080/ping; echo

agent-ask: ## Pose une question à l'agent : make agent-ask Q="..."
	@curl -s -X POST http://localhost:8080/invocations \
	  -H 'Content-Type: application/json' \
	  -d "$$(jq -n --arg q "$(Q)" '{prompt: $$q}')" | jq -r '.reponse // .'

clean: ## Supprime les fichiers locaux de Terraform (state compris !)
	find . -name '.terraform' -type d -prune -exec rm -rf {} +
	find . \( -name 'terraform.tfstate*' -o -name '.terraform.lock.hcl' -o -name 'localstack_providers_override.tf' \) -delete
