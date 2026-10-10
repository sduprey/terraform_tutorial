# Tutoriel Terraform : du zéro à l'extraction d'un compte AWS

Ce tutoriel accompagne les exercices de [`EXERCICES.md`](EXERCICES.md). Lis
chaque leçon avant l'exercice correspondant. Les leçons 0 à 4 portent sur
Terraform ; la leçon 5 sur un agent IA (intelligence artificielle) local avec
Ollama et AgentCore.

Chaque leçon se termine par un lien vers l'exercice correspondant. Sous chaque
énoncé, une **solution repliée** (« 💡 Solution ») te permet de vérifier ton
travail sans changer de fichier.

---

## Leçon 0 : le modèle mental

Terraform est un outil d'IaC (Infrastructure as Code, infrastructure décrite
sous forme de code). Il repose sur trois éléments :

| Élément | Ce que c'est |
|---|---|
| **Le code** | Les fichiers `.tf`, écrits en HCL (HashiCorp Configuration Language). Ils décrivent l'état **voulu**. |
| **Le state** | Le fichier `terraform.tfstate`, en JSON (JavaScript Object Notation). Il associe chaque ressource du code à un objet réel, via son identifiant chez AWS (Amazon Web Services). |
| **Le réel** | Ce qui existe vraiment dans le compte, interrogé par l'API (Application Programming Interface) du fournisseur. |

- `terraform plan` calcule la différence entre ces trois éléments.
- `terraform apply` fait converger le réel vers le code.

Le langage est **déclaratif** : tu décris un point fixe, et Terraform calcule
le chemin pour y arriver, sous la forme d'un graphe de dépendances orienté
acyclique.

> Le state est le cœur du système. Un expert Terraform est avant tout
> quelqu'un qui sait manipuler le state sans rien casser.

### State ou réel : quelle différence ?

Les deux semblent décrire « ce qui existe ». Ils ne le décrivent pas de la
même manière.

- **Le réel** est ce qu'AWS répond **maintenant** quand on l'interroge, avec
  l'AWS CLI (Command Line Interface) ou la console.
- **Le state** est le carnet de notes de Terraform, un fichier sur ton disque.
  Il ne décrit pas le monde. Il note **ce que Terraform gère, et à quoi ça
  correspond chez AWS** :

  ```
  aws_vpc.main  →  vpc-1a2b3c   (vu la dernière fois avec cidr 10.42.0.0/16, dns_hostnames=true…)
  ```

  Il sert donc à deux choses : **le lien** entre un nom du code et un objet
  réel, et **une photo** des attributs telle que Terraform les a vus la
  dernière fois.

On les consulte avec des outils différents :

```bash
aws ec2 describe-vpcs              # le réel
terraform state list               # le state : ce que Terraform gère
terraform state show aws_vpc.main  # le state : la photo d'une ressource
```

Une analogie : le réel est le contenu d'un entrepôt, le state est le registre
du magasinier (« l'étagère B3, c'est moi qui m'en occupe, et la dernière fois
il y avait 12 cartons »), et le code est la consigne (« il doit y avoir
12 cartons en B3 »). Le registre peut se tromper. Quelqu'un a pu prendre un
carton sans le noter : c'est le **drift** (leçon 3). Un objet peut aussi être
dans l'entrepôt sans figurer au registre : le magasinier l'ignore
complètement.

Dans le labo, les trois éléments évoluent ainsi :

| Moment | Réel | State | Code |
|---|---|---|---|
| Après `make setup` (exercice 1) | 8 objets | **vide** | vide |
| Après l'import (exercice 2) | 8 objets | 8 entrées liées aux identifiants | 8 ressources |
| Modification à la main dans la console (exercice 4) | règle ajoutée | ancienne photo | inchangé |

La première ligne est tout l'enjeu de l'extraction. Le réel existe, mais
**Terraform ne le voit pas**, puisque rien ne figure dans son state. Si tu
écrivais `resource "aws_vpc" "main" {...}` sans importer, Terraform créerait un
**deuxième** VPC. Le bloc `import` (leçon 1) remplit le state : « ce
`vpc-1a2b3c` existant, c'est `aws_vpc.main` ».

`terraform plan` procède en trois temps :

1. **Refresh** : pour chaque entrée du state, il interroge le réel et met la
   photo à jour.
2. **Comparaison** : il compare cette photo fraîche avec le code.
3. **Proposition** : il liste les actions qui feraient correspondre le réel au
   code.

> Seuls les objets déjà dans le state sont rafraîchis. Terraform n'explore
> jamais ton compte à la recherche d'objets inconnus.

### Le vocabulaire

```hcl
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {               # le "pilote" qui parle à l'API AWS
  region = "eu-west-3"
}

variable "env" {               # une entrée
  type    = string
  default = "dev"
}

locals {                       # des valeurs calculées en interne
  prefix = "lab-${var.env}"
}

data "aws_caller_identity" "me" {} # une LECTURE d'un objet existant, non géré

resource "aws_s3_bucket" "demo" {  # un objet GÉRÉ par Terraform
  bucket = "${local.prefix}-demo"
}

output "bucket_arn" {          # une sortie
  value = aws_s3_bucket.demo.arn
}
```

Le `module` complète ce vocabulaire : c'est un dossier de ressources
réutilisable, l'équivalent d'une fonction.

### La boucle de travail

```bash
terraform init       # télécharge les providers et configure le backend
terraform fmt        # formate le code
terraform validate   # vérifie la syntaxe et la cohérence
terraform plan       # montre ce qui va changer
terraform apply      # applique
terraform destroy    # supprime tout ce qui est géré
```

Dans ce laboratoire, tu remplaces `terraform` par `tflocal`, qui redirige vers
LocalStack.

### Lire un plan

| Symbole | Signification | Danger |
|---|---|---|
| `+` | création | faible |
| `~` | modification en place | moyen |
| `-` | destruction | élevé |
| `-/+` | destruction puis recréation | **très élevé** sur une base de données |

Un attribut marqué `# forces replacement` explique pourquoi une ressource est
recréée.

> ▶ **À toi de jouer :** [Exercice 1 : créer le legacy](EXERCICES.md#ex1). La solution est repliée juste sous chaque énoncé.

---

## Leçon 1 : importer un compte existant

### Le problème

Le réel existe déjà, créé à la main. Le code et le state sont vides. Il faut
produire les deux **sans modifier le réel**.

### Étape 1 : déclarer ce qu'on importe

```hcl
import {
  to = aws_vpc.main
  id = "vpc-0abc123"
}
```

- `to` est l'adresse de la ressource dans ton code.
- `id` est son identifiant chez AWS. Il peut être une expression, par exemple
  `var.vpc_id`, depuis Terraform 1.6.

Le format de l'`id` dépend du type de ressource. La documentation de chaque
ressource, sur le Terraform Registry, l'indique dans sa section « Import ».
Exemples courants :

| Ressource | Format de l'`id` |
|---|---|
| `aws_vpc`, `aws_subnet`, `aws_security_group` | l'identifiant AWS (`vpc-…`, `subnet-…`, `sg-…`) |
| `aws_s3_bucket` | le nom du bucket S3 (Simple Storage Service) |
| `aws_iam_role` | le nom du rôle IAM (Identity and Access Management) |
| `aws_iam_role_policy_attachment` | `nom-du-role/arn-de-la-politique` |
| `aws_sqs_queue` | l'**URL** de la file SQS (Simple Queue Service), pas son nom |
| `aws_secretsmanager_secret` | l'ARN (Amazon Resource Name) complet |

### Étape 2 : faire générer le code

```bash
terraform plan -generate-config-out=generated.tf
```

Terraform interroge AWS et écrit le code correspondant à chaque bloc `import`
qui n'a pas encore de ressource associée. Le résultat est fidèle, mais très
verbeux :

```hcl
resource "aws_subnet" "a" {
  vpc_id                          = "vpc-0abc123"
  cidr_block                      = "10.42.1.0/24"
  availability_zone               = "eu-west-3a"
  map_public_ip_on_launch         = false
  assign_ipv6_address_on_creation = false
  enable_dns64                    = false
  ipv6_native                     = false
  tags = {
    Name   = "lab-subnet-a"
    Projet = "terraform-lab"
  }
  # … et une dizaine d'autres lignes
}
```

Il arrive que le code généré contienne des arguments contradictoires, et que
le plan échoue. Corrige-les à la main dans `generated.tf`, puis relance
`terraform plan`, cette fois sans l'option.

### Étape 3 : nettoyer, le vrai travail d'expert

Après nettoyage, le même sous-réseau devient :

```hcl
resource "aws_subnet" "a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.42.1.0/24"
  availability_zone = "eu-west-3a"
  tags              = { Name = "lab-subnet-a" }
}
```

Le nettoyage suit six règles.

1. **Remplacer les IDs (identifiants) en dur par des références.** Écris
   `aws_vpc.main.id` au lieu de `"vpc-0abc123"`. C'est ce qui construit le
   graphe de dépendances.
2. **Supprimer les valeurs par défaut.** Pour vérifier qu'un attribut est
   inutile, supprime la ligne et relance le plan : s'il reste vide, elle
   l'était.
3. **Factoriser les tags communs** avec `default_tags` dans le provider :
   ```hcl
   provider "aws" {
     default_tags { tags = { Projet = "terraform-lab" } }
   }
   ```
4. **Rendre les politiques JSON lisibles.** Le code généré les met dans une
   chaîne pleine de `\"`. Réécris-les avec `jsonencode({ ... })`. Le provider
   compare le JSON sémantiquement : l'ordre des clés et les espaces ne créent
   pas d'écart.
5. **Supprimer les arguments qui en doublonnent d'autres.** Par exemple,
   `managed_policy_arns` sur un rôle entre en conflit avec des ressources
   `aws_iam_role_policy_attachment` séparées. Choisis une seule méthode.
6. **Protéger ce qui contient de la donnée** :
   ```hcl
   lifecycle { prevent_destroy = true }
   ```

### Étape 4 : le critère de réussite

```
Plan: 8 to import, 0 to add, 0 to change, 0 to destroy.
```

Ensuite :

1. `terraform apply` écrit uniquement dans le state, rien ne bouge chez AWS.
2. Supprime les blocs `import`, devenus inutiles.
3. `terraform plan` doit afficher **« No changes. »**

> ▶ **À toi de jouer :** [Exercice 2 : importer et nettoyer](EXERCICES.md#ex2). La solution est repliée juste sous chaque énoncé.

---

## Leçon 2 : réorganiser sans casser

### Le problème

Pour Terraform, `aws_vpc.main` et `module.network.aws_vpc.main` sont deux
adresses différentes. Si tu déplaces le code dans un module sans précaution,
le plan **détruit l'ancienne ressource et crée la nouvelle**.

### La solution : `moved`

```hcl
moved {
  from = aws_vpc.main
  to   = module.network.aws_vpc.main
}
```

Écris un bloc par ressource déplacée. Le plan doit n'afficher que des lignes
« has moved to », sans aucun ajout ni aucune suppression.

Les blocs `moved` sont préférables à `terraform state mv` :

- ils sont dans le code, donc relus en revue de code ;
- ils sont rejoués automatiquement sur chaque environnement et chaque copie du
  state ;
- ils ne demandent aucune manipulation manuelle du state.

### `for_each` plutôt que `count`

```hcl
resource "aws_subnet" "this" {
  for_each   = var.subnets             # map : { a = {...}, b = {...} }
  vpc_id     = aws_vpc.main.id
  cidr_block = each.value.cidr_block
}

moved {
  from = aws_subnet.a
  to   = module.network.aws_subnet.this["a"]
}
```

`count` indexe les instances par position : `[0]`, `[1]`, `[2]`. Si tu
supprimes l'élément `[0]`, tous les suivants sont décalés, et Terraform recrée
tout ce qui suit. `for_each` indexe par clé : supprimer `"a"` ne touche jamais
à `"b"`.

### Les autres outils de chirurgie du state

| Besoin | Méthode déclarative (préférée) | Commande ponctuelle |
|---|---|---|
| Renommer, déplacer | `moved {}` (Terraform 1.1 et plus) | `terraform state mv` |
| Oublier sans détruire | `removed {}` (Terraform 1.7 et plus) | `terraform state rm` |
| Reprendre un existant | `import {}` (Terraform 1.5 et plus) | `terraform import` |
| Inspecter | — | `terraform state list` et `terraform state show` |

> ▶ **À toi de jouer :** [Exercice 3 : modules et `moved`](EXERCICES.md#ex3). La solution est repliée juste sous chaque énoncé.

---

## Leçon 3 : le drift

Le drift est l'écart qui apparaît quand quelqu'un modifie le réel hors de
Terraform, par exemple dans la console AWS.

```bash
terraform plan -refresh-only  # ce qui a changé dans le réel, sans rien proposer de modifier
terraform plan                # ce que Terraform ferait pour revenir au code
```

Pour chaque écart, tu as deux choix :

- l'**adopter** : tu reportes la modification dans le code ;
- le **corriger** : tu laisses `apply` remettre le réel en conformité avec le
  code.

### Le piège des règles inline

Un bloc `ingress` ou `egress` écrit à l'intérieur d'un `aws_security_group` est
**exhaustif** : Terraform considère qu'il liste toutes les règles. Une règle
ajoutée à la main apparaîtra comme un écart, et Terraform proposera de la
supprimer.

À l'inverse, si tu gères les règles avec des ressources séparées
(`aws_vpc_security_group_ingress_rule`), une règle ajoutée à la main **passe
inaperçue**. Les deux styles sont incompatibles sur un même groupe : choisis-en
un.

> ▶ **À toi de jouer :** [Exercice 4 : drift](EXERCICES.md#ex4) · [Exercice 5 : détruire](EXERCICES.md#ex5). La solution est repliée juste sous chaque énoncé.

---

## Leçon 4 : passer à l'échelle d'un vrai compte

### Le state en équipe

Ne laisse jamais le state en local sur une mission. Stocke-le dans un backend
distant :

```hcl
terraform {
  backend "s3" {
    bucket       = "monclient-tfstate"
    key          = "reseau/terraform.tfstate"
    region       = "eu-west-3"
    encrypt      = true
    use_lockfile = true   # verrouillage natif dans S3 depuis Terraform 1.10, plus besoin de DynamoDB
  }
}
```

Les secrets finissent **en clair** dans le state. Chiffre donc le backend,
restreins son accès via IAM et ne versionne jamais le state dans Git.

### Découper en plusieurs states

Plutôt qu'un seul state monolithique, découpe par couche : réseau, données,
applicatif. Une couche lit les sorties de l'autre avec
`data "terraform_remote_state"` ou, mieux, avec des `data` sources AWS (par
exemple `data "aws_vpc"` filtré par tag).

Ce découpage a trois avantages :

- une erreur dans le code applicatif ne peut pas toucher au réseau ;
- les plans restent rapides ;
- les droits peuvent être séparés par équipe.

### Automatiser l'inventaire

`outils/generer_imports.py` interroge la Resource Groups Tagging API et IAM,
puis écrit un bloc `import` par ressource reconnue. Il couvre une quarantaine
de types courants. Ses limites :

- **Les ressources jamais taguées** sont parfois invisibles à l'API de tags :
  règles de groupes de sécurité, routes, tables de routage par défaut.
- **Les ressources « filles »** n'apparaissent pas dans l'inventaire : le
  versioning d'un bucket S3, sa politique, son cycle de vie. Ce sont pourtant
  des ressources Terraform distinctes, à importer explicitement.
- **Les objets gérés par AWS** ne doivent jamais être importés : rôles
  `aws-service-role/`, VPC (Virtual Private Cloud) par défaut, clés KMS (Key
  Management Service) gérées par AWS.

> ▶ **À toi de jouer :** [Bonus : le générateur d'imports](EXERCICES.md#exbonus). La solution est repliée juste sous chaque énoncé.

---

## Leçon 5 : un agent IA (intelligence artificielle) en local avec Ollama et AgentCore

Cette leçon sort de Terraform pour aborder ce que les clients demandent de plus
en plus : des agents IA déployés sur AWS. Tout se fait gratuitement sur ton Mac.

### Les trois briques

| Brique | Rôle | En local | Sur AWS |
|---|---|---|---|
| **Ollama** | Fait tourner un LLM (Large Language Model, grand modèle de langage) | ✅ sur ton Mac | remplacé par Amazon Bedrock |
| **Strands Agents** | La boucle d'agent : le modèle raisonne, appelle des outils, lit le résultat, recommence | ✅ | ✅ identique |
| **AgentCore Runtime** | Héberge l'agent derrière un contrat HTTP (HyperText Transfer Protocol) standard | ✅ via le SDK (Software Development Kit) | ✅ service géré |

LocalStack **n'émule pas** AgentCore, et son émulation de Bedrock est réservée
à son offre payante. Ollama remplace donc Bedrock, et le SDK `bedrock-agentcore`
reproduit le contrat du Runtime sur ta machine.

### Le contrat AgentCore Runtime

L'agent est un petit serveur qui écoute sur le **port 8080** :

- `POST /invocations` reçoit le JSON (JavaScript Object Notation) envoyé par
  l'appelant et renvoie la réponse ;
- `GET /ping` sert de contrôle de santé.

Le SDK fournit ce serveur. Tu n'écris que la fonction d'entrée :

```python
from bedrock_agentcore import BedrockAgentCoreApp
from strands import Agent
from strands.models.ollama import OllamaModel

app = BedrockAgentCoreApp()
agent = Agent(
    model=OllamaModel(host="http://localhost:11434", model_id="llama3.2"),
    tools=[...],
)

@app.entrypoint
def invoquer(payload: dict) -> dict:
    return {"reponse": str(agent(payload["prompt"]))}

app.run()  # port 8080
```

Le fichier complet est `agent-local/agent.py`.

### Les outils : là où se joue la sécurité

Un outil est une fonction Python décorée par `@tool`. Le modèle lit sa
**docstring** pour décider quand l'appeler : elle doit dire précisément ce que
fait l'outil et ce que signifie chaque argument.

```python
from strands import tool

@tool
def lister_ressources_state(dossier: str = "exercice-files") -> str:
    """Liste les ressources gérées par Terraform dans le state d'un dossier.

    Args:
        dossier: dossier relatif à la racine du dépôt.
    """
```

Les outils du laboratoire appliquent trois règles qui valent pour tout agent en
production :

1. **Lecture seule.** Aucun outil n'écrit, ne lance de commande ni n'appelle
   AWS. Un agent qui aurait accès à `terraform apply` pourrait détruire une
   base de données sur une simple erreur d'interprétation.
2. **Chemins confinés.** Les outils refusent tout fichier hors du dépôt, ce qui
   empêche par exemple de lire `~/.aws/credentials`.
3. **Données minimisées.** Le state peut contenir des secrets en clair :
   l'agent n'en reçoit qu'un résumé (adresses, identifiants, tags).

### Choisir le modèle

Le modèle doit **savoir appeler des outils** (tool calling). Le catalogue
d'Ollama propose un filtre « tools » pour les trouver.

| Modèle | Taille | Mémoire conseillée | Remarque |
|---|---|---|---|
| `llama3.2` | 3 milliards de paramètres | 8 Go | rapide, mais se trompe plus souvent |
| `qwen3:8b` | 8 milliards de paramètres | 16 Go | nettement plus fiable sur les appels d'outils |

Sur un Mac à puce Apple, Ollama utilise automatiquement le GPU (Graphics
Processing Unit, processeur graphique) intégré.

### Passer sur AWS le jour venu

1. **Le modèle :** remplace Ollama par Bedrock, sans changer le reste du code :
   ```bash
   AGENT_FOURNISSEUR=bedrock make agent-run MODELE=<identifiant du modèle Bedrock>
   ```
2. **L'hébergement :** construis une image de conteneur pour l'architecture
   **ARM64**, la seule acceptée par AgentCore Runtime :
   ```bash
   docker buildx build --platform linux/arm64 -t mon-agent .
   ```
   Pousse-la ensuite dans Amazon ECR (Elastic Container Registry) et
   déclare-la dans AgentCore Runtime, par exemple avec le CLI (Command Line
   Interface) AgentCore.
3. **Les briques gérées :** Memory, Gateway, Identity, Code Interpreter et
   Browser n'existent que sur AWS. Il te faudra un vrai compte pour les
   tester.

> ▶ **À toi de jouer :** [Exercice 6 : agent IA local](EXERCICES.md#ex6). La solution est repliée juste sous chaque énoncé.

---

## Ce qui fait passer pour expert auprès du client

1. **Commencer en lecture seule.** Pendant toute la phase d'inventaire, ton
   rôle sur le compte client n'a aucun droit d'écriture.
2. **Faire valider le découpage cible** (states et modules) avant d'écrire la
   moindre ligne.
3. **Importer state par state, jusqu'au plan vide.** Un plan vide est la
   preuve que le code décrit fidèlement le réel.
4. **Poser `prevent_destroy` partout où il y a de la donnée.**
5. **Ne jamais appliquer sans plan relu.** Dans la chaîne CI/CD (Continuous
   Integration / Continuous Delivery, intégration et livraison continues),
   `plan` tourne à chaque merge request et `apply` n'a lieu qu'après
   validation humaine.
6. **Figer les versions.** Utilise `required_version`, contraint le provider
   avec `~> 5.0` et versionne `.terraform.lock.hcl`.
7. **Détecter le drift chaque nuit** avec `plan -refresh-only` et une alerte en
   cas d'écart.
8. **Analyser le code statiquement** avec `tflint` pour les erreurs et
   `checkov` pour les mauvaises pratiques de sécurité.

Un mot sur la licence : Terraform est sous BSL (Business Source License) depuis
2023. OpenTofu en est le fork open source, compatible à l'usage. Demande au
client lequel il utilise : les commandes sont les mêmes, mais les registres de
providers diffèrent.
