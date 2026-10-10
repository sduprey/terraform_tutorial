#!/usr/bin/env python3
"""
Générateur de blocs `import` Terraform à partir de l'inventaire d'un compte AWS
(Amazon Web Services).

Principe
--------
1. Interroge la Resource Groups Tagging API (API = Application Programming
   Interface) région par région : elle renvoie l'ARN (Amazon Resource Name) de
   presque toutes les ressources taguées ou ayant déjà été taguées.
2. Interroge IAM (Identity and Access Management) séparément (service global,
   mal couvert par l'API de tags) : rôles, utilisateurs, politiques gérées par
   le client, attachements de politiques aux rôles.
3. Traduit chaque ARN en (type de ressource Terraform, id d'import) via la
   table REGLES ci-dessous.
4. Écrit :
     - imports.tf          : un bloc import par ressource reconnue
     - providers.tf        : un provider aliasé par région (si plusieurs)
     - non_reconnues.csv   : les ARN sans règle, à traiter à la main

Ensuite :  terraform init && terraform plan -generate-config-out=generated.tf

Ce script est en LECTURE SEULE : il n'appelle que des API List/Get/Describe.
Droits nécessaires : tag:GetResources, iam:List*, sts:GetCallerIdentity
(la politique gérée ReadOnlyAccess suffit).

Exemples
--------
  python3 generer_imports.py --regions eu-west-3 eu-west-1 --iam
  python3 generer_imports.py --regions eu-west-3 --tag Projet=terraform-lab
  python3 generer_imports.py --from-json inventaire.json   # hors ligne, sans AWS
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


# ---------------------------------------------------------------------------
# Table de traduction ARN -> Terraform
#
# Format d'un ARN : arn:partition:service:region:compte:ressource
# Chaque règle : (service, motif regex sur la partie "ressource", type
# Terraform, fonction qui calcule l'id d'import à partir du match et de l'ARN).
# Les formats d'id viennent de la section « Import » de la documentation du
# provider hashicorp/aws v5. Ajoute tes propres règles au besoin.
# ---------------------------------------------------------------------------

def g1(m, a):            # premier groupe capturé
    return m.group(1)


def arn(m, a):           # l'ARN complet
    return a.arn


def sqs_url(m, a):       # SQS (Simple Queue Service) s'importe par son URL
    return f"https://sqs.{a.region}.amazonaws.com/{a.account}/{m.group(1)}"


REGLES = [
    # EC2 (Elastic Compute Cloud) et réseau VPC (Virtual Private Cloud)
    ("ec2", r"^vpc/(vpc-[0-9a-f]+)$",                 "aws_vpc", g1),
    ("ec2", r"^subnet/(subnet-[0-9a-f]+)$",           "aws_subnet", g1),
    ("ec2", r"^security-group/(sg-[0-9a-f]+)$",       "aws_security_group", g1),
    ("ec2", r"^internet-gateway/(igw-[0-9a-f]+)$",    "aws_internet_gateway", g1),
    ("ec2", r"^natgateway/(nat-[0-9a-f]+)$",          "aws_nat_gateway", g1),
    ("ec2", r"^route-table/(rtb-[0-9a-f]+)$",         "aws_route_table", g1),
    ("ec2", r"^network-acl/(acl-[0-9a-f]+)$",         "aws_network_acl", g1),
    ("ec2", r"^elastic-ip/(eipalloc-[0-9a-f]+)$",     "aws_eip", g1),
    ("ec2", r"^vpc-endpoint/(vpce-[0-9a-f]+)$",       "aws_vpc_endpoint", g1),
    ("ec2", r"^instance/(i-[0-9a-f]+)$",              "aws_instance", g1),
    ("ec2", r"^volume/(vol-[0-9a-f]+)$",              "aws_ebs_volume", g1),
    ("ec2", r"^launch-template/(lt-[0-9a-f]+)$",      "aws_launch_template", g1),
    ("ec2", r"^key-pair/(key-[0-9a-f]+)$",            None, None),  # import par nom, cf. note
    # Stockage et données
    ("s3", r"^([^/]+)$",                              "aws_s3_bucket", g1),
    ("dynamodb", r"^table/([^/]+)$",                  "aws_dynamodb_table", g1),
    ("rds", r"^db:(.+)$",                             "aws_db_instance", g1),
    ("rds", r"^cluster:(.+)$",                        "aws_rds_cluster", g1),
    ("rds", r"^subgrp:(.+)$",                         "aws_db_subnet_group", g1),
    ("elasticache", r"^cluster:(.+)$",                "aws_elasticache_cluster", g1),
    # Calcul serverless et conteneurs
    ("lambda", r"^function:([^:]+)$",                 "aws_lambda_function", g1),
    ("ecr", r"^repository/(.+)$",                     "aws_ecr_repository", g1),
    ("ecs", r"^cluster/(.+)$",                        "aws_ecs_cluster", g1),
    ("eks", r"^cluster/(.+)$",                        "aws_eks_cluster", g1),
    # Messagerie et événements
    ("sqs", r"^([^:/]+)$",                            "aws_sqs_queue", sqs_url),
    ("sns", r"^([^:/]+)$",                            "aws_sns_topic", arn),
    ("events", r"^rule/([^/]+)$",                     "aws_cloudwatch_event_rule", g1),
    ("states", r"^stateMachine:(.+)$",                "aws_sfn_state_machine", arn),
    # Observabilité, sécurité
    ("logs", r"^log-group:(.+?)(:\*)?$",              "aws_cloudwatch_log_group", g1),
    ("kms", r"^key/(.+)$",                            "aws_kms_key", g1),
    ("secretsmanager", r"^secret:(.+)$",              "aws_secretsmanager_secret", arn),
    ("ssm", r"^parameter(/.+)$",                      "aws_ssm_parameter", g1),
    ("acm", r"^certificate/(.+)$",                    "aws_acm_certificate", arn),
    # Équilibrage de charge
    ("elasticloadbalancing", r"^loadbalancer/(app|net)/.+$", "aws_lb", arn),
    ("elasticloadbalancing", r"^targetgroup/.+$",     "aws_lb_target_group", arn),
    # IAM (Identity and Access Management) — alimenté par lister_iam()
    ("iam", r"^role/(?:.*/)?([^/]+)$",                "aws_iam_role", g1),
    ("iam", r"^user/(?:.*/)?([^/]+)$",                "aws_iam_user", g1),
    ("iam", r"^policy/.+$",                           "aws_iam_policy", arn),
    ("iam", r"^attach:(.+)$",                         "aws_iam_role_policy_attachment", g1),
]
REGLES = [(s, re.compile(p), t, f) for s, p, t, f in REGLES]


@dataclass
class Arn:
    arn: str
    service: str
    region: str
    account: str
    resource: str
    nom: str | None = None  # tag Name, utilisé pour nommer la ressource Terraform

    @classmethod
    def parse(cls, arn_str: str, nom: str | None = None) -> "Arn":
        parts = arn_str.split(":", 5)
        if len(parts) != 6 or parts[0] != "arn":
            raise ValueError(f"ARN invalide : {arn_str}")
        _, _, service, region, account, resource = parts
        return cls(arn_str, service, region, account, resource, nom)


def traduire(a: Arn):
    """Renvoie (type_terraform, id_import) ou None si aucune règle."""
    for service, motif, tf_type, fn in REGLES:
        if service != a.service:
            continue
        m = motif.match(a.resource)
        if m and tf_type:
            return tf_type, fn(m, a)
    return None


# ---------------------------------------------------------------------------
# Collecte depuis AWS
# ---------------------------------------------------------------------------

def lister_par_tags(session, regions, filtre_tag):
    tag_filters = []
    if filtre_tag:
        cle, _, valeur = filtre_tag.partition("=")
        tag_filters = [{"Key": cle, "Values": [valeur]}] if valeur else [{"Key": cle}]

    for region in regions:
        client = session.client("resourcegroupstaggingapi", region_name=region)
        pages = client.get_paginator("get_resources").paginate(TagFilters=tag_filters)
        for page in pages:
            for r in page["ResourceTagMappingList"]:
                tags = {t["Key"]: t["Value"] for t in r.get("Tags", [])}
                a = Arn.parse(r["ResourceARN"], tags.get("Name"))
                # Les buckets S3 (Simple Storage Service) ont un ARN sans région :
                # on garde la région interrogée pour choisir le bon provider.
                if not a.region:
                    a.region = region
                yield a


def lister_iam(session, region_defaut):
    iam = session.client("iam")
    compte = session.client("sts").get_caller_identity()["Account"]

    for page in iam.get_paginator("list_roles").paginate():
        for role in page["Roles"]:
            # Rôles créés et gérés par AWS : ne jamais les importer.
            if role["Path"].startswith("/aws-service-role/") or \
               role["Path"].startswith("/aws-reserved/"):
                continue
            yield Arn(role["Arn"], "iam", region_defaut, compte, f"role/{role['RoleName']}")
            pol = iam.get_paginator("list_attached_role_policies")
            for p in pol.paginate(RoleName=role["RoleName"]):
                for att in p["AttachedPolicies"]:
                    id_import = f"{role['RoleName']}/{att['PolicyArn']}"
                    yield Arn(f"{role['Arn']}#{att['PolicyName']}", "iam", region_defaut,
                              compte, f"attach:{id_import}",
                              nom=f"{role['RoleName']}-{att['PolicyName']}")

    for page in iam.get_paginator("list_users").paginate():
        for user in page["Users"]:
            yield Arn(user["Arn"], "iam", region_defaut, compte, f"user/{user['UserName']}")

    for page in iam.get_paginator("list_policies").paginate(Scope="Local"):
        for pol in page["Policies"]:
            yield Arn(pol["Arn"], "iam", region_defaut, compte,
                      f"policy/{pol['PolicyName']}", nom=pol["PolicyName"])


# ---------------------------------------------------------------------------
# Génération du HCL (HashiCorp Configuration Language)
# ---------------------------------------------------------------------------

def nom_terraform(a: Arn, id_import: str, deja_pris: Counter, tf_type: str) -> str:
    """Identifiant Terraform lisible, unique par type."""
    base = a.nom or id_import.rsplit("/", 1)[-1].rsplit(":", 1)[-1]
    base = re.sub(r"[^a-zA-Z0-9_]", "_", base).strip("_").lower() or "res"
    if base[0].isdigit():
        base = "r_" + base
    base = base[:60]
    deja_pris[(tf_type, base)] += 1
    n = deja_pris[(tf_type, base)]
    return base if n == 1 else f"{base}_{n}"


def alias_region(region: str) -> str:
    return region.replace("-", "_")


def generer(arns, sortie: Path, region_defaut: str):
    sortie.mkdir(parents=True, exist_ok=True)
    noms = Counter()
    blocs, inconnus, regions = [], [], set()
    vus = set()

    for a in arns:
        if a.arn in vus:
            continue
        vus.add(a.arn)
        tr = traduire(a)
        if tr is None:
            inconnus.append(a)
            continue
        tf_type, id_import = tr
        regions.add(a.region or region_defaut)
        blocs.append((a, tf_type, id_import, nom_terraform(a, id_import, noms, tf_type)))

    multi = len(regions) > 1
    blocs.sort(key=lambda b: (b[1], b[3]))

    with open(sortie / "imports.tf", "w") as f:
        f.write("# Généré par outils/generer_imports.py — à relire avant usage.\n")
        f.write("# Étape suivante : terraform plan -generate-config-out=generated.tf\n\n")
        type_courant = None
        for a, tf_type, id_import, nom in blocs:
            if tf_type != type_courant:
                f.write(f"# --- {tf_type} {'-' * max(3, 70 - len(tf_type))}\n\n")
                type_courant = tf_type
            f.write("import {\n")
            f.write(f"  to = {tf_type}.{nom}\n")
            f.write(f"  id = {json.dumps(id_import)}\n")
            reg = a.region or region_defaut
            if multi and a.service != "iam":
                f.write(f"  provider = aws.{alias_region(reg)}\n")
            f.write("}\n\n")

    if multi:
        with open(sortie / "providers.tf", "w") as f:
            f.write("# Un provider par région. Celui sans alias sert aux ressources globales (IAM).\n\n")
            f.write(f'provider "aws" {{\n  region = "{region_defaut}"\n}}\n\n')
            for reg in sorted(regions):
                f.write(f'provider "aws" {{\n  alias  = "{alias_region(reg)}"\n'
                        f'  region = "{reg}"\n}}\n\n')

    with open(sortie / "non_reconnues.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["service", "region", "ressource", "nom", "arn"])
        for a in sorted(inconnus, key=lambda x: (x.service, x.resource)):
            w.writerow([a.service, a.region, a.resource, a.nom or "", a.arn])

    stats = Counter(b[1] for b in blocs)
    print(f"{len(blocs)} blocs import écrits dans {sortie / 'imports.tf'}")
    for tf_type, n in stats.most_common():
        print(f"  {n:4d}  {tf_type}")
    if multi:
        print(f"Providers multi-régions écrits dans {sortie / 'providers.tf'}")
    print(f"{len(inconnus)} ressources sans règle -> {sortie / 'non_reconnues.csv'}")


# ---------------------------------------------------------------------------

def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--regions", nargs="+", default=["eu-west-3"])
    p.add_argument("--tag", help="Filtre Cle=Valeur (ou Cle seule)")
    p.add_argument("--iam", action="store_true", help="Inclure rôles, utilisateurs et politiques IAM")
    p.add_argument("--profile", help="Profil AWS CLI (Command Line Interface) à utiliser")
    p.add_argument("--sortie", default="extraction", help="Dossier de sortie")
    p.add_argument("--from-json", help="Liste d'ARN ou de {arn, nom} en JSON, pour tester hors ligne")
    args = p.parse_args(argv)

    region_defaut = args.regions[0]

    if args.from_json:
        brut = json.loads(Path(args.from_json).read_text())
        arns = []
        for x in brut:
            a = Arn.parse(x) if isinstance(x, str) else Arn.parse(x["arn"], x.get("nom"))
            a.region = a.region or region_defaut
            arns.append(a)
    else:
        try:
            import boto3
        except ImportError:
            sys.exit("boto3 manquant : pip install boto3")
        session = boto3.Session(profile_name=args.profile)
        arns = list(lister_par_tags(session, args.regions, args.tag))
        if args.iam:
            arns += list(lister_iam(session, region_defaut))

    generer(arns, Path(args.sortie), region_defaut)


if __name__ == "__main__":
    main()
