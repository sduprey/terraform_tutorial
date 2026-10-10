# =============================================================================
# Blocs moved : ils disent à Terraform « cette ressource n'est pas nouvelle,
# elle a juste changé d'adresse ». Sans eux, le plan détruirait tout et
# recréerait tout dans les modules.
#
# Avantage sur `terraform state mv` : c'est dans le code, donc relu en revue de
# code (merge request), rejoué automatiquement sur chaque environnement, et
# sans manipulation manuelle du state.
#
# On peut les supprimer une fois appliqués partout (ou les garder quelque temps
# pour les autres copies du state).
# =============================================================================

# Réseau
moved {
  from = aws_vpc.main
  to   = module.network.aws_vpc.main
}

moved {
  from = aws_subnet.a
  to   = module.network.aws_subnet.this["a"]
}

moved {
  from = aws_subnet.b
  to   = module.network.aws_subnet.this["b"]
}

moved {
  from = aws_security_group.web
  to   = module.network.aws_security_group.web
}

# Application
moved {
  from = aws_s3_bucket.data
  to   = module.app.aws_s3_bucket.data
}

moved {
  from = aws_s3_bucket_versioning.data
  to   = module.app.aws_s3_bucket_versioning.data
}

moved {
  from = aws_iam_role.app
  to   = module.app.aws_iam_role.app
}

moved {
  from = aws_iam_role_policy_attachment.app_s3_read
  to   = module.app.aws_iam_role_policy_attachment.this["arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"]
}
