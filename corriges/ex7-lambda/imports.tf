# Corrigé de l'exercice 7 — les 7 blocs import.
# À supprimer une fois le premier terraform apply passé.

import {
  to = aws_iam_role.lambda
  id = var.role_name
}

# Format composé, et la politique est rangée sous service-role/ :
# l'oublier donne une erreur « policy not attached » à l'import.
import {
  to = aws_iam_role_policy_attachment.lambda_sqs
  id = "${var.role_name}/arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

# Une file SQS (Simple Queue Service) s'importe par son URL, pas par son nom.
import {
  to = aws_sqs_queue.jobs
  id = var.queue_url
}

import {
  to = aws_cloudwatch_log_group.worker
  id = "/aws/lambda/${var.function_name}"
}

import {
  to = aws_lambda_function.worker
  id = var.function_name
}

# Format composé : "<nom de la fonction>/<nom de l'alias>"
import {
  to = aws_lambda_alias.live
  id = "${var.function_name}/live"
}

# Le déclencheur n'a pas de nom : il s'importe par l'UUID qu'AWS lui a donné
# (aws lambda list-event-source-mappings --function-name <fonction>).
import {
  to = aws_lambda_event_source_mapping.jobs
  id = var.mapping_uuid
}
