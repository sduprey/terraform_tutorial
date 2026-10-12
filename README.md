# Terraform Lab : extraire un compte AWS existant

Laboratoire pratique pour apprendre à **reprendre sous Terraform une
infrastructure AWS (Amazon Web Services) déjà en place**, sans rien recréer ni
casser. Tout tourne en local sur **LocalStack**, un émulateur des API
(Application Programming Interface) AWS : pas de compte AWS, pas de carte
bancaire, aucun risque.

Ce que tu sauras faire à la fin :

- importer des ressources existantes avec les blocs `import` et `-generate-config-out` ;
- nettoyer le code généré jusqu'à obtenir un plan vide ;
- restructurer en modules sans recréation, avec les blocs `moved` ;
- détecter et traiter le drift (modifications faites hors Terraform) ;
- générer automatiquement les blocs `import` d'un compte réel entier ;
- extraire des fonctions Lambda en récupérant leur code, qui n'existe souvent
  que dans AWS ;
- écrire et protéger une base de graphe Neptune, et repérer les plans qui
  détruiraient ses données ;
- faire tourner en local un agent IA (intelligence artificielle) qui lit ton
  code Terraform, avec Ollama, Strands Agents et le Runtime Amazon Bedrock
  AgentCore.

## Démarrage rapide (macOS)

```bash
make install     # Terraform, AWS CLI, OrbStack (Docker), Ollama, tflocal, .venv Python
make start       # démarre LocalStack et vérifie ec2, s3, iam, sts, lambda, sqs, logs
make setup       # exercice 1 : crée l'infrastructure "à la main" dans LocalStack
cd exercice-files
tflocal init
tflocal plan -generate-config-out=generated.tf
```

Pour les fonctions Lambda (exercice 7) : `make setup-lambda`, puis `cd exercice-lambda`.

Pour l'agent IA (exercice 6) :

```bash
make ollama-pull   # télécharge le modèle llama3.2, une seule fois
make agent-run     # sert l'agent sur http://localhost:8080
make agent-ask Q="Quelles ressources sont dans le state de exercice-files ?"
```

`make help` liste toutes les commandes.

**Prérequis :** macOS avec [Homebrew](https://brew.sh). Le script installe le
reste. AWS CLI désigne l'interface en ligne de commande d'AWS (Amazon Web
Services Command Line Interface).

> **`tflocal` au lieu de `terraform`.** `tflocal` est une surcouche fournie par
> le paquet `terraform-local`. Elle redirige automatiquement tous les appels du
> provider AWS vers LocalStack (`http://localhost:4566`), sans toucher au code.
> Le jour où tu travailles sur un vrai compte, tu reprends `terraform` et le
> même code fonctionne.

### Jeton LocalStack (optionnel)

Depuis mars 2026, les versions récentes de LocalStack exigent un compte gratuit
et un jeton d'authentification. Sans jeton, le script utilise automatiquement la
dernière image Community qui n'en demande pas (`4.12`), suffisante pour ce
laboratoire. Avec un compte sur localstack.cloud :

```bash
export LOCALSTACK_AUTH_TOKEN=ton-jeton
make start
```

## Contenu

| Chemin | Rôle |
|---|---|
| [`TUTORIEL.md`](TUTORIEL.md) | Le cours : concepts, import, `moved`, drift, pièges, agent IA local, Lambda, Neptune |
| [`EXERCICES.md`](EXERCICES.md) | Les 8 exercices pas à pas, avec critères de réussite et **solution repliée sous chaque énoncé** |
| `scripts/` | Installation macOS, pilotage de LocalStack, variables d'environnement |
| `00-setup/` | Création et suppression de l'infrastructure « legacy » via l'AWS CLI (réseau et application Lambda) |
| `exercice-files/` | **Ton dossier de travail** (exercices 2 à 5) : tu complètes `imports.tf`, le reste est fourni ou généré |
| `exercice-lambda/` | Dossier de travail de l'exercice 7 (fonctions Lambda), avec son propre state |
| `exercice-neptune/` | Dossier de travail de l'exercice 8 (Neptune), validé hors ligne, sans AWS |
| `corriges/ex2-plat/` | Corrigé de l'import et du nettoyage |
| `corriges/ex3-modules/` | Corrigé de la restructuration en modules (`moved`) |
| `corriges/ex6-agent/` | Corrigé de l'outil ajouté à l'agent |
| `corriges/ex7-lambda/` | Corrigé de l'extraction Lambda, code de la fonction compris (`src/`) |
| `corriges/ex8-neptune/` | Corrigé de la base Neptune protégée |
| `outils/generer_imports.py` | Générateur de blocs `import` pour un vrai compte |
| `agent-local/` | Agent IA : Strands Agents + Ollama, servi au format AgentCore Runtime |
| `tests/` | Tests du générateur et de l'agent (sans Ollama) |
| `.github/workflows/` | CI (Continuous Integration, intégration continue) : `fmt`, `validate`, tests |

## Différences entre LocalStack et un vrai compte AWS

- **Les droits IAM (Identity and Access Management) ne sont pas appliqués** :
  les rôles existent, mais aucun appel n'est jamais refusé.
- **Le code généré peut contenir quelques attributs que LocalStack renvoie
  différemment d'AWS.** Si un attribut provoque un écart impossible à
  supprimer, retire-le du code : c'est l'émulateur, pas ton travail.
- **Les données sont effacées à chaque arrêt**, sauf si tu démarres avec
  `PERSISTENCE=1 make start`.

Le comportement de Terraform lui-même (import, state, `moved`, drift) est
strictement identique à celui sur AWS.

## Utilisation sur un vrai compte

Le code des exercices et des corrigés fonctionne sans modification sur AWS,
avec `terraform` au lieu de `tflocal`. Le script `00-setup/creer-infra-manuelle.sh`
demande une confirmation explicite s'il détecte qu'il ne vise pas LocalStack.

Pour un compte client, utilise `outils/generer_imports.py`. Il est **en
lecture seule** : il n'appelle que des API List, Get ou Describe.

```bash
.venv/bin/python outils/generer_imports.py --profile client-ro \
  --regions eu-west-3 eu-west-1 --iam --sortie extraction
```

## Publier sur GitHub

```bash
git init
git add .
git commit -m "Laboratoire Terraform : extraction d'un compte AWS"
gh repo create terraform-lab --private --source=. --push
```

Le `.gitignore` exclut déjà les states, les fichiers `.terraform/`, les
identifiants générés et l'environnement Python.

## Licence

MIT, voir [`LICENSE`](LICENSE).
