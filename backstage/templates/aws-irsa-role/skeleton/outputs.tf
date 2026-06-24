output "role_arn" {
  description = "ARN da role IRSA."
  value       = aws_iam_role.this.arn
}

output "service_account_annotation" {
  description = "Annotation para usar no ServiceAccount Kubernetes."
  value = {
    "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn
  }
}

