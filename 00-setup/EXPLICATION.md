# Que fait `make setup` ?

`make setup` joue le rôle du collègue qui a tout créé « à la main » dans la
console AWS, sans Terraform. Il fabrique une petite infrastructure dans
LocalStack. Dans les exercices suivants, tu devras la faire passer sous
contrôle de Terraform **sans rien recréer**.

Rien n'est envoyé sur un vrai compte AWS : tout se passe dans le conteneur
LocalStack lancé par `make start`.

---

## 1. La cible du Makefile

```make
LS_ENV := env -u AWS_PROFILE AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_REGION=eu-west-3 \
          AWS_DEFAULT_REGION=eu-west-3 AWS_ENDPOINT_URL=http://localhost:4566

setup:
	$(LS_ENV) ./00-setup/creer-infra-manuelle.sh
```

Avant de lancer le script, `make` place des variables d'environnement
**uniquement pour cette commande** :

| Variable | Valeur | Rôle |
|---|---|---|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | `test` | Identifiants factices : LocalStack les accepte, un vrai AWS les refuserait. |
| `AWS_REGION` / `AWS_DEFAULT_REGION` | `eu-west-3` | Région de Paris. |
| `AWS_ENDPOINT_URL` | `http://localhost:4566` | **La clé de tout** : l'AWS CLI envoie ses requêtes à LocalStack au lieu d'Amazon. |
| `AWS_PROFILE` | supprimée (`env -u`) | Ignore un éventuel profil de `~/.aws/config` qui pointerait vers un vrai compte. La supprimer, et non la laisser vide : avec `AWS_PROFILE=`, l'AWS CLI v2 cherche un profil au nom vide et échoue. |

Ton terminal n'est pas modifié. Pour avoir ces variables dans ton shell
(pour lancer toi-même des commandes `aws`), utilise
`source scripts/env-localstack.sh`.

---

## 2. Le script `creer-infra-manuelle.sh`, étape par étape

### 2.1 Préparation

```bash
set -euo pipefail
REGION="${AWS_REGION:-eu-west-3}"
SUFFIX="$(date +%s)"
OUT_DIR=".../exercice-files"
```

- `set -euo pipefail` : le script s'arrête à la première erreur, ou dès
  qu'une variable n'est pas définie.
- `SUFFIX` : l'heure actuelle en secondes (par ex. `1791630000`). Il rend
  uniques les noms du bucket S3 et du rôle IAM, qui doivent l'être.
- `OUT_DIR` : le dossier où seront écrits les identifiants, `exercice-files/`.

La petite fonction `tags` fabrique la syntaxe de tags attendue par
`aws ec2 ... --tag-specifications`. Chaque ressource reçoit deux tags :
`Name=<nom>` et `Projet=terraform-lab`. C'est ce second tag qui permet de
retrouver « tout ce qui appartient au labo ».

### 2.2 Garde-fou

```bash
if [ -n "${AWS_ENDPOINT_URL:-}" ]; then
  echo ">> Mode LocalStack : $AWS_ENDPOINT_URL"
else
  echo ">> ATTENTION : aucun AWS_ENDPOINT_URL, tu vises un VRAI compte AWS."
  read -r -p "   Continuer ? (oui/non) " rep
  ...
```

Si le script est lancé sans `AWS_ENDPOINT_URL`, il viserait un vrai compte
AWS : il demande alors de confirmer. Avec `make setup`, la variable est
toujours définie, donc tu verras simplement `Mode LocalStack`.

Il affiche ensuite le compte utilisé (`aws sts get-caller-identity`). Avec
LocalStack, c'est le compte factice `000000000000`.

### 2.3 Le réseau : VPC et sous-réseaux

```bash
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.42.0.0/16 ... --query Vpc.VpcId --output text)
aws ec2 wait vpc-available --vpc-ids "$VPC_ID"
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames '{"Value":true}'
```

- Crée un VPC (réseau privé) avec la plage d'adresses `10.42.0.0/16`.
- `--query Vpc.VpcId --output text` extrait de la réponse JSON juste
  l'identifiant (`vpc-xxxx`), stocké dans `VPC_ID`. Le script fait la même
  chose pour chaque ressource.
- `wait` attend que le VPC soit prêt, puis active les noms DNS (Domain Name
  System) des machines.

> 💡 Ce dernier réglage compte pour la suite : c'est un attribut **modifié
> après la création**. Le code généré par Terraform devra le refléter, sinon
> le `plan` voudra le changer.

Ensuite, deux sous-réseaux en `/24` sont créés dans deux zones de
disponibilité (`eu-west-3a` et `eu-west-3b`) :

| Nom | Plage | Zone |
|---|---|---|
| `lab-subnet-a` | `10.42.1.0/24` | `eu-west-3a` |
| `lab-subnet-b` | `10.42.2.0/24` | `eu-west-3b` |

### 2.4 Le groupe de sécurité

```bash
SG_ID=$(aws ec2 create-security-group --group-name lab-web --vpc-id "$VPC_ID" ...)
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --ip-permissions 'IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges=[{CidrIp=0.0.0.0/0,...}]'
```

Un pare-feu `lab-web` rattaché au VPC, puis une règle qui autorise le HTTPS
(TCP, port 443) depuis n'importe où (`0.0.0.0/0`).

### 2.5 Le bucket S3

```bash
BUCKET_NAME="lab-tf-${SUFFIX}"
aws s3api create-bucket --bucket "$BUCKET_NAME" \
  --create-bucket-configuration LocationConstraint="$REGION"
aws s3api put-bucket-tagging    ...
aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --versioning-configuration Status=Enabled
```

- Hors de `us-east-1`, S3 exige `LocationConstraint` : d'où le `if` dans le
  script.
- Les tags et le versioning sont posés par **des appels séparés**. Côté
  Terraform, le versioning est d'ailleurs une ressource à part
  (`aws_s3_bucket_versioning`). C'est pour ça que l'exercice 2 compte un bloc
  `import` pour le bucket et un autre pour son versioning.

### 2.6 Le rôle IAM

```bash
ROLE_NAME="lab-app-role-${SUFFIX}"
aws iam create-role --role-name "$ROLE_NAME" --assume-role-policy-document '{ ... ec2.amazonaws.com ... sts:AssumeRole ... }'
aws iam attach-role-policy --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
```

- La « politique de confiance » (`assume-role-policy-document`) dit **qui**
  peut endosser le rôle : ici, le service EC2, donc une future machine
  virtuelle.
- `attach-role-policy` dit **ce que** le rôle peut faire : lire S3, grâce à
  une politique gérée par AWS.
- L'attachement est un objet à part entière. En Terraform, c'est
  `aws_iam_role_policy_attachment`, dont l'`id` d'import a un format composé :
  c'est le piège annoncé dans l'exercice 2.

### 2.7 Écriture des identifiants

```bash
cat > "$OUT_DIR/terraform.tfvars" <<EOF
region      = "$REGION"
vpc_id      = "$VPC_ID"
...
role_name   = "$ROLE_NAME"
EOF
cp "$OUT_DIR/terraform.tfvars" "$(dirname "$0")/ids-crees.tfvars"
```

Le script écrit tous les identifiants récupérés dans deux fichiers :

- **`exercice-files/terraform.tfvars`** : Terraform le lit automatiquement. Il
  remplit les variables déclarées dans `exercice-files/variables.tf`, que les
  blocs `import` utilisent (`id = var.vpc_id`).
- **`00-setup/ids-crees.tfvars`** : une copie de secours, lue par
  `make destroy-manual` pour tout supprimer sans Terraform.

Ces deux fichiers sont dans le `.gitignore` : ils ne valent que pour ton
LocalStack.

---

## 3. En résumé

```
make setup
  └─ creer-infra-manuelle.sh   (AWS CLI → LocalStack sur localhost:4566)
       ├─ VPC  10.42.0.0/16  (+ DNS hostnames)
       │    ├─ subnet a  10.42.1.0/24
       │    ├─ subnet b  10.42.2.0/24
       │    └─ security group lab-web  (443 entrant)
       ├─ bucket S3  lab-tf-<horodatage>  (versionné)
       ├─ rôle IAM   lab-app-role-<horodatage>
       │    └─ politique AmazonS3ReadOnlyAccess attachée
       └─ écrit les identifiants dans exercice-files/terraform.tfvars
```

Ça fait **8 objets à importer** dans l'exercice 2 : le VPC, 2 sous-réseaux, le
groupe de sécurité, le bucket, son versioning, le rôle et l'attachement de la
politique.

---

## 4. À savoir avant de le lancer

- **Le script n'est pas idempotent.** Le relancer crée un **deuxième** jeu de
  ressources (nouveaux noms horodatés, nouveaux identifiants) et **écrase**
  `terraform.tfvars`. Le premier jeu reste alors orphelin dans LocalStack.
  Pour repartir de zéro, passe plutôt par `make reset` puis
  `make start` et `make setup`.
- **LocalStack oublie tout à l'arrêt** (`PERSISTENCE=0`). Après `make stop` ou
  un redémarrage du Mac, refais `make start` puis `make setup`. Les anciens
  identifiants de `terraform.tfvars` ne correspondront plus à rien.
- **Vérifier le résultat** :

  ```bash
  source scripts/env-localstack.sh
  aws ec2 describe-vpcs --filters Name=tag:Projet,Values=terraform-lab
  aws s3 ls
  aws iam list-roles --query 'Roles[].RoleName'
  cat exercice-files/terraform.tfvars
  ```
