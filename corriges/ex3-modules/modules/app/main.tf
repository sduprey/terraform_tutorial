resource "aws_s3_bucket" "data" {
  bucket = var.bucket_name

  tags = { Name = "lab-bucket" }

  lifecycle {
    prevent_destroy = true # à retirer avant l'exercice 5 (destroy)
  }
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_iam_role" "app" {
  name        = var.role_name
  description = "Lab Terraform - role applicatif"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "lab-app-role" }
}

# Indexé par l'ARN (Amazon Resource Name) de la politique : ajouter une
# politique à la liste n'en recrée aucune autre.
resource "aws_iam_role_policy_attachment" "this" {
  for_each = var.role_managed_policy_arns

  role       = aws_iam_role.app.name
  policy_arn = each.value
}
