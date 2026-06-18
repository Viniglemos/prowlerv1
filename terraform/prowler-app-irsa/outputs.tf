output "role_arn" {
  description = "IRSA role ARN to use in the Helm serviceAccount annotation."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "IRSA role name."
  value       = aws_iam_role.this.name
}

output "service_account_annotation" {
  description = "Helm annotation key/value for the Prowler App ServiceAccount."
  value = {
    "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn
  }
}
