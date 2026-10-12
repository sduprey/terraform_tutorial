# =============================================================================
# Corrigé de l'exercice 7 — l'application Lambda après nettoyage (fin du 7.d).
#
# Ce qui a été fait par rapport au code généré :
#   1. Ajout de la source du code, que le générateur ne peut pas écrire :
#      AWS ne rend le zip que par une URL temporaire, jamais par l'API de
#      configuration. Le code récupéré est rangé dans src/ et rezippé par
#      archive_file.
#   2. Suppression des valeurs par défaut (architectures, package_type,
#      ephemeral_storage, tracing_config, logging_config, enabled, etc.).
#   3. Remplacement des ARN (Amazon Resource Name) en dur par des références :
#      rôle, file, alias.
#   4. Politique d'approbation du rôle réécrite avec jsonencode().
#   5. Suppression du tag Projet : default_tags s'en charge.
#   6. depends_on vers le groupe de journaux : il doit exister avant la
#      fonction, sinon Lambda le crée lui-même, sans rétention ni tags.
#
# Critère de réussite après 7.c : aucun ajout, aucune destruction.
# Après 7.d : un seul changement, le source_code_hash de la fonction.
# =============================================================================

# --- Identité -----------------------------------------------------------------

resource "aws_iam_role" "lambda" {
  name        = var.role_name
  description = "Lab Terraform - role d'execution Lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "lab-lambda-role" }
}

# Donne à la fonction le droit de lire la file et d'écrire ses journaux.
resource "aws_iam_role_policy_attachment" "lambda_sqs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

# --- File de messages ---------------------------------------------------------

resource "aws_sqs_queue" "jobs" {
  name                       = var.queue_name
  visibility_timeout_seconds = 60 # AWS exige >= timeout de la fonction (30 s)

  tags = { Name = "lab-jobs" }
}

# --- Fonction -----------------------------------------------------------------

# Rezippe le code de src/ à chaque plan. Le hash ne change que si le code
# change, et c'est lui qui déclenche le redéploiement.
data "archive_file" "worker" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/build/worker.zip"
}

# Nom construit à partir de la variable, pas de la fonction : la fonction
# dépend du groupe (depends_on plus bas), une référence inverse ferait un cycle.
resource "aws_cloudwatch_log_group" "worker" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 14

  tags = { Name = "lab-worker-logs" }
}

resource "aws_lambda_function" "worker" {
  function_name = var.function_name
  description   = "Lab Terraform - traite les messages de la file lab-jobs"
  role          = aws_iam_role.lambda.arn
  runtime       = "python3.12"
  handler       = "app.handler"
  timeout       = 30
  memory_size   = 256

  filename         = data.archive_file.worker.output_path
  source_code_hash = data.archive_file.worker.output_base64sha256

  environment {
    variables = { NIVEAU_LOG = "INFO" }
  }

  tags = { Name = "lab-worker" }

  depends_on = [
    aws_cloudwatch_log_group.worker,
    aws_iam_role_policy_attachment.lambda_sqs,
  ]
}

# Version écrite en dur, et non aws_lambda_function.worker.version : sans
# publish = true, cet attribut vaut "$LATEST". Conséquence : modifier le code
# met à jour $LATEST, mais l'alias, donc le déclencheur, exécute toujours la
# version 1 (voir la question d'expert du 7.d).
resource "aws_lambda_alias" "live" {
  name             = "live"
  function_name    = aws_lambda_function.worker.function_name
  function_version = "1"
}

# --- Déclencheur --------------------------------------------------------------

# Branché sur l'alias, pas sur la fonction : c'est l'alias qui décide quelle
# version reçoit les messages.
resource "aws_lambda_event_source_mapping" "jobs" {
  event_source_arn = aws_sqs_queue.jobs.arn
  function_name    = aws_lambda_alias.live.arn
  batch_size       = 5
}
