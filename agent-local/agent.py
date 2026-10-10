"""
Agent Terraform local : Strands Agents + Ollama, servi par le Runtime AgentCore.

- Strands Agents fournit la boucle d'agent (raisonnement, appels d'outils).
- Ollama fait tourner le modèle de langage sur ton Mac, gratuitement.
- BedrockAgentCoreApp, du SDK (Software Development Kit, kit de développement)
  bedrock-agentcore, expose l'agent avec le contrat HTTP (HyperText Transfer
  Protocol) d'Amazon Bedrock AgentCore Runtime : POST /invocations et
  GET /ping, sur le port 8080.

Ce fichier se déploie tel quel sur AgentCore Runtime. Seul le modèle change :
voir la variable AGENT_FOURNISSEUR.

Lancement : make agent-run   (ou : .venv/bin/python agent-local/agent.py)
Appel     : make agent-ask Q="Quelles ressources sont dans mon state ?"
"""
from __future__ import annotations

import os
from functools import lru_cache

from bedrock_agentcore import BedrockAgentCoreApp
from strands import Agent

from outils_terraform import OUTILS

CONSIGNES = """Tu es un assistant Terraform pour un laboratoire d'extraction de compte AWS.
Réponds en français, de façon concise.
Avant d'affirmer quoi que ce soit sur le code ou le state, utilise tes outils pour le lire.
N'invente jamais d'adresse Terraform, d'identifiant ou d'attribut : si tu ne le trouves pas, dis-le.
Quand tu utilises un acronyme, écris sa forme développée."""


def construire_modele():
    fournisseur = os.getenv("AGENT_FOURNISSEUR", "ollama")
    if fournisseur == "ollama":
        from strands.models.ollama import OllamaModel
        return OllamaModel(
            host=os.getenv("OLLAMA_HOST", "http://localhost:11434"),
            model_id=os.getenv("AGENT_MODELE", "llama3.2"),
            temperature=0.1,
        )
    if fournisseur == "bedrock":
        # Le jour où tu as un vrai compte AWS : AGENT_FOURNISSEUR=bedrock
        from strands.models import BedrockModel
        return BedrockModel(model_id=os.environ["AGENT_MODELE"])
    raise ValueError(f"AGENT_FOURNISSEUR inconnu : {fournisseur}")


@lru_cache(maxsize=1)
def obtenir_agent() -> Agent:
    return Agent(model=construire_modele(), tools=OUTILS, system_prompt=CONSIGNES)


app = BedrockAgentCoreApp()


@app.entrypoint
def invoquer(payload: dict) -> dict:
    question = payload.get("prompt")
    if not isinstance(question, str) or not question.strip():
        return {"erreur": "Le champ 'prompt' doit être une chaîne non vide."}
    resultat = obtenir_agent()(question)
    return {"reponse": str(resultat).strip()}


if __name__ == "__main__":
    app.run()  # port 8080 par défaut, comme sur AgentCore Runtime
