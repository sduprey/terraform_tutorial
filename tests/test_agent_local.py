"""Tests de l'agent local, sans Ollama : le modèle est remplacé par un faux agent."""
import json
import sys
from pathlib import Path

import pytest

pytest.importorskip("strands")
pytest.importorskip("bedrock_agentcore")
from starlette.testclient import TestClient  # noqa: E402

RACINE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RACINE / "agent-local"))

import agent as agent_mod  # noqa: E402
import outils_terraform as outils  # noqa: E402

STATE = {
    "version": 4,
    "resources": [
        {"mode": "managed", "type": "aws_vpc", "name": "main",
         "instances": [{"attributes": {"id": "vpc-1", "tags": {"Name": "lab-vpc"}}}]},
        {"module": "module.network", "mode": "managed", "type": "aws_subnet", "name": "this",
         "instances": [{"index_key": "a", "attributes": {"id": "subnet-a"}},
                       {"index_key": "b", "attributes": {"id": "subnet-b"}}]},
        {"mode": "managed", "type": "aws_instance", "name": "web",
         "instances": [{"index_key": 0, "attributes": {"id": "i-0"}}]},
        {"mode": "data", "type": "aws_caller_identity", "name": "me",
         "instances": [{"attributes": {"id": "123"}}]},
    ],
}


def test_resume_state(tmp_path):
    f = tmp_path / "terraform.tfstate"
    f.write_text(json.dumps(STATE))
    adresses = [l["adresse"] for l in outils.resumer_state(f)]
    assert adresses == [
        "aws_vpc.main",
        'module.network.aws_subnet.this["a"]',
        'module.network.aws_subnet.this["b"]',
        "aws_instance.web[0]",
    ]  # les data sources sont exclues


def test_chemin_hors_depot_refuse():
    with pytest.raises(ValueError):
        outils._dans_le_depot("../../../etc/passwd")


def test_lecture_limitee_aux_fichiers_tf():
    texte = outils.lire_fichier_terraform._tool_func("exercice-files/variables.tf")
    assert 'variable "vpc_id"' in texte
    refus = outils.lire_fichier_terraform._tool_func("README.md")
    assert "Seuls les fichiers .tf" in refus


class FauxAgent:
    def __call__(self, question):
        return f"  écho : {question}  "


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setattr(agent_mod, "obtenir_agent", lambda: FauxAgent())
    return TestClient(agent_mod.app)


def test_ping(client):
    r = client.get("/ping")
    assert r.status_code == 200
    assert r.json()["status"].lower() == "healthy"


def test_invocation(client):
    r = client.post("/invocations", json={"prompt": "Que contient mon state ?"})
    assert r.status_code == 200
    assert r.json() == {"reponse": "écho : Que contient mon state ?"}


def test_prompt_vide(client):
    r = client.post("/invocations", json={"prompt": "  "})
    assert "erreur" in r.json()


def test_corrige_ex6_compter_par_type(tmp_path, monkeypatch):
    sys.path.insert(0, str(RACINE / "corriges" / "ex6-agent"))
    import compter_par_type as corrige

    (tmp_path / "lab").mkdir()
    (tmp_path / "lab" / "terraform.tfstate").write_text(json.dumps(STATE))
    monkeypatch.setattr(outils, "RACINE", tmp_path)

    resultat = corrige.compter_par_type._tool_func("lab")
    assert resultat == "aws_instance : 1\naws_subnet : 2\naws_vpc : 1"
    assert "Aucun state" in corrige.compter_par_type._tool_func(".")
