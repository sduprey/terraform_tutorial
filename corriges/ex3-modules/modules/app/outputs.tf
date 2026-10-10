output "bucket_arn" {
  value = aws_s3_bucket.data.arn
}

output "role_arn" {
  value = aws_iam_role.app.arn
}
