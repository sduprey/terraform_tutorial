"""
Outils donnés à l'agent : lecture SEULE des fichiers du laboratoire.

Règles de sécurité appliquées (à reprendre sur un vrai projet) :
  - aucun outil n'écrit, ne lance de commande ni n'appelle AWS (Amazon Web Services) ;
  - les chemins sont confinés au dépôt : impossible de lire ~/.aws/credentials ;
  - le state n'est jamais renvoyé brut, car il peut contenir des secrets en
    clair : l'agent n'en voit qu'un résumé (adresses et identifiants).
"""
from __future__ import annotations

import json
from pathlib import Path

from strands import tool

RACINE = Path(__file__).resolve().parents[1]
TAILLE_MAX = 20_000  # caractères renvoyés au modèle au maximum


def _dans_le_depot(chemin: str) -> Path:
    p = (RACINE / chemin).resolve()
    if p != RACINE and RACINE not in p.parents:
        raise ValueError(f"Chemin hors du dépôt refusé : {chemin}")
    return p


def resumer_state(fichier_state: Path) -> list[dict]:
    """Extrait adresse, type et identifiant de chaque instance du state."""
    state = json.loads(fichier_state.read_text())
    lignes = []
    for r in state.get("resources", []):
        if r.get("mode") != "managed":
            continue
        prefixe = f"{r['module']}." if r.get("module") else ""
        base = f"{prefixe}{r['type']}.{r['name']}"
        for inst in r.get("instances", []):
            cle = inst.get("index_key")
            if cle is None:
                adresse = base
            elif isinstance(cle, str):
                adresse = f'{base}["{cle}"]'
            else:
                adresse = f"{base}[{cle}]"
            attributs = inst.get("attributes", {})
            lignes.append({
                "adresse": adresse,
                "type": r["type"],
                "id": attributs.get("id"),
                "tags": attributs.get("tags") or {},
            })
    return lignes


@tool
def lister_ressources_state(dossier: str = "01-exercice") -> str:
    """Liste les ressources gérées par Terraform dans le state d'un dossier du
    laboratoire : adresse Terraform, type, identifiant AWS et tags.

    Args:
        dossier: dossier relatif à la racine du dépôt, par défaut "01-exercice".
    """
    fichier = _dans_le_depot(dossier) / "terraform.tfstate"
    if not fichier.exists():
        return f"Aucun state dans {dossier} : rien n'a encore été appliqué."
    lignes = resumer_state(fichier)
    if not lignes:
        return f"Le state de {dossier} est vide."
    return json.dumps(lignes, ensure_ascii=False, indent=2)[:TAILLE_MAX]


@tool
def lister_fichiers_terraform(dossier: str = "01-exercice") -> str:
    """Liste les fichiers .tf d'un dossier du laboratoire (sous-dossiers compris).

    Args:
        dossier: dossier relatif à la racine du dépôt.
    """
    base = _dans_le_depot(dossier)
    fichiers = sorted(p.relative_to(RACINE).as_posix()
                      for p in base.rglob("*.tf") if ".terraform" not in p.parts)
    return "\n".join(fichiers) or f"Aucun fichier .tf dans {dossier}."


@tool
def lire_fichier_terraform(chemin: str) -> str:
    """Renvoie le contenu d'un fichier .tf du laboratoire.

    Args:
        chemin: chemin relatif à la racine du dépôt, par exemple
            "corriges/ex2-plat/main.tf".
    """
    p = _dans_le_depot(chemin)
    if p.suffix != ".tf":
        return "Seuls les fichiers .tf sont lisibles (ni state, ni tfvars, ni secrets)."
    if not p.exists():
        return f"Fichier introuvable : {chemin}"
    return p.read_text()[:TAILLE_MAX]


OUTILS = [lister_ressources_state, lister_fichiers_terraform, lire_fichier_terraform]
