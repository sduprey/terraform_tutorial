# Corrigé de l'exercice 2 — les 8 blocs import.
# À supprimer une fois le premier terraform apply passé : les ressources sont
# alors dans le state et ces blocs ne servent plus à rien.

import {
  to = aws_vpc.main
  id = var.vpc_id
}

import {
  to = aws_subnet.a
  id = var.subnet_a_id
}

import {
  to = aws_subnet.b
  id = var.subnet_b_id
}

import {
  to = aws_security_group.web
  id = var.sg_id
}

import {
  to = aws_s3_bucket.data
  id = var.bucket_name
}

import {
  to = aws_s3_bucket_versioning.data
  id = var.bucket_name
}

import {
  to = aws_iam_role.app
  id = var.role_name
}

# Format composé : "<nom du rôle>/<ARN (Amazon Resource Name) de la politique>"
import {
  to = aws_iam_role_policy_attachment.app_s3_read
  id = "${var.role_name}/arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}
