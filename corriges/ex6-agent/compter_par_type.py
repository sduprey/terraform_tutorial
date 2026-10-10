"""
Corrigé de l'exercice 6.c.

À copier dans agent-local/outils_terraform.py (sans la ligne d'import
ci-dessous, inutile dans ce fichier), puis ajouter compter_par_type à la liste
OUTILS en bas du fichier.
"""
from collections import Counter

from strands import tool

from outils_terraform import _dans_le_depot, resumer_state


@tool
def compter_par_type(dossier: str = "01-exercice") -> str:
    """Compte les ressources gérées par Terraform dans le state d'un dossier du
    laboratoire, par type de ressource (par exemple « aws_subnet : 2 »).
    Utilise cet outil pour toute question du type « combien de ... ».

    Args:
        dossier: dossier relatif à la racine du dépôt, par défaut "01-exercice".
    """
    fichier = _dans_le_depot(dossier) / "terraform.tfstate"
    if not fichier.exists():
        return f"Aucun state dans {dossier} : rien n'a encore été appliqué."
    compte = Counter(ligne["type"] for ligne in resumer_state(fichier))
    if not compte:
        return f"Le state de {dossier} est vide."
    return "\n".join(f"{type_} : {n}" for type_, n in sorted(compte.items()))
