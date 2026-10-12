"""
Garde-fous sur les solutions recopiées dans EXERCICES.md :
  - chaque bloc précédé de <!-- fichier: chemin --> doit être identique au
    fichier corrigé correspondant (sinon le corrigé et l'énoncé divergent) ;
  - chaque lien EXERCICES.md#ancre du tutoriel doit pointer vers une ancre
    existante.
"""
import re
from pathlib import Path

RACINE = Path(__file__).resolve().parents[1]
EXERCICES = (RACINE / "EXERCICES.md").read_text()
TUTORIEL = (RACINE / "TUTORIEL.md").read_text()

BLOC = re.compile(r"<!-- fichier: (?P<chemin>\S+) -->\n.*?\n```\w*\n(?P<code>.*?)\n```", re.S)


def test_les_solutions_recopiees_sont_a_jour():
    blocs = list(BLOC.finditer(EXERCICES))
    assert len(blocs) >= 11, "des solutions recopiées ont disparu d'EXERCICES.md"
    for b in blocs:
        attendu = (RACINE / b["chemin"]).read_text().rstrip("\n")
        assert b["code"] == attendu, f"{b['chemin']} diffère de sa copie dans EXERCICES.md"


def test_chaque_exercice_a_sa_solution():
    sections = re.split(r'<a id="ex\w+"></a>', EXERCICES)[1:]
    assert len(sections) == 9  # exercices 1 à 8 + bonus
    for i, section in enumerate(sections):
        assert "💡" in section, f"section {i + 1} sans solution"


def test_liens_du_tutoriel_vers_les_exercices():
    ancres = set(re.findall(r'<a id="(ex\w+)"></a>', EXERCICES))
    liens = set(re.findall(r"EXERCICES\.md#(\w+)", TUTORIEL))
    assert liens, "le tutoriel ne renvoie vers aucun exercice"
    assert liens <= ancres, f"ancres inexistantes : {liens - ancres}"
    assert ancres <= liens, f"exercices jamais cités dans le tutoriel : {ancres - liens}"
