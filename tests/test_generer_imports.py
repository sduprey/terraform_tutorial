"""Tests du générateur de blocs import (outils/generer_imports.py), sans AWS."""
import csv
import importlib.util
import json
import sys
from pathlib import Path

import pytest

RACINE = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("gen", RACINE / "outils" / "generer_imports.py")
gen = importlib.util.module_from_spec(spec)
sys.modules["gen"] = gen  # requis par dataclasses
spec.loader.exec_module(gen)


@pytest.mark.parametrize("arn, attendu", [
    ("arn:aws:ec2:eu-west-3:123456789012:vpc/vpc-0a1b2c3d", ("aws_vpc", "vpc-0a1b2c3d")),
    ("arn:aws:ec2:eu-west-3:123456789012:subnet/subnet-0aa11", ("aws_subnet", "subnet-0aa11")),
    ("arn:aws:ec2:eu-west-3:123456789012:security-group/sg-0123", ("aws_security_group", "sg-0123")),
    ("arn:aws:s3:::mon-bucket", ("aws_s3_bucket", "mon-bucket")),
    ("arn:aws:rds:eu-west-3:123456789012:db:prod-pg", ("aws_db_instance", "prod-pg")),
    ("arn:aws:lambda:eu-west-3:123456789012:function:ingest", ("aws_lambda_function", "ingest")),
    ("arn:aws:logs:eu-west-3:123456789012:log-group:/aws/lambda/x:*",
     ("aws_cloudwatch_log_group", "/aws/lambda/x")),
    ("arn:aws:iam::123456789012:role/app/prod-role", ("aws_iam_role", "prod-role")),
])
def test_traduction(arn, attendu):
    a = gen.Arn.parse(arn)
    a.region = a.region or "eu-west-3"
    assert gen.traduire(a) == attendu


def test_sqs_importe_par_url():
    a = gen.Arn.parse("arn:aws:sqs:eu-west-3:123456789012:ma-file")
    assert gen.traduire(a) == (
        "aws_sqs_queue", "https://sqs.eu-west-3.amazonaws.com/123456789012/ma-file")


def test_attachement_iam_id_compose():
    a = gen.Arn("arn:aws:iam::1:role/r#P", "iam", "eu-west-3", "1",
                "attach:mon-role/arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess")
    assert gen.traduire(a) == (
        "aws_iam_role_policy_attachment",
        "mon-role/arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess")


def test_ressource_inconnue():
    assert gen.traduire(gen.Arn.parse("arn:aws:glue:eu-west-3:1:job/etl")) is None


def test_arn_invalide():
    with pytest.raises(ValueError):
        gen.Arn.parse("pas-un-arn")


def test_generation_complete(tmp_path):
    inventaire = [
        {"arn": "arn:aws:ec2:eu-west-3:1:vpc/vpc-aaa", "nom": "prod-vpc"},
        {"arn": "arn:aws:ec2:eu-west-3:1:vpc/vpc-bbb", "nom": "prod-vpc"},  # nom en double
        {"arn": "arn:aws:ec2:eu-west-1:1:instance/i-ccc", "nom": "bastion"},
        "arn:aws:iam::1:role/app-role",
        "arn:aws:glue:eu-west-3:1:job/etl",
        "arn:aws:ec2:eu-west-3:1:vpc/vpc-aaa",                             # ARN en double
    ]
    fichier = tmp_path / "inv.json"
    fichier.write_text(json.dumps(inventaire))
    sortie = tmp_path / "out"

    gen.main(["--from-json", str(fichier), "--regions", "eu-west-3", "--sortie", str(sortie)])

    imports = (sortie / "imports.tf").read_text()
    assert imports.count("import {") == 4                 # doublon d'ARN ignoré, glue écarté
    assert "aws_vpc.prod_vpc\n" in imports
    assert "aws_vpc.prod_vpc_2\n" in imports              # noms uniques
    assert "provider = aws.eu_west_1" in imports          # multi-régions
    bloc_iam = imports.split("aws_iam_role.app_role")[1].split("}")[0]
    assert "provider" not in bloc_iam                     # IAM est global

    providers = (sortie / "providers.tf").read_text()
    assert 'alias  = "eu_west_1"' in providers

    with open(sortie / "non_reconnues.csv") as f:
        lignes = list(csv.DictReader(f))
    assert [l["service"] for l in lignes] == ["glue"]


def test_une_seule_region_pas_de_providers(tmp_path):
    fichier = tmp_path / "inv.json"
    fichier.write_text(json.dumps(["arn:aws:s3:::b1", "arn:aws:ec2:eu-west-3:1:vpc/vpc-a"]))
    sortie = tmp_path / "out"
    gen.main(["--from-json", str(fichier), "--regions", "eu-west-3", "--sortie", str(sortie)])
    assert not (sortie / "providers.tf").exists()
    assert "provider =" not in (sortie / "imports.tf").read_text()
