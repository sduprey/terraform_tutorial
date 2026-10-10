variable "bucket_name" {
  type = string
}

variable "role_name" {
  type = string
}

variable "role_managed_policy_arns" {
  description = "Politiques gérées attachées au rôle applicatif"
  type        = set(string)
  default     = ["arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"]
}
