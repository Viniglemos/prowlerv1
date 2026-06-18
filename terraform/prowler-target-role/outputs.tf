output "role_arn" {
  description = "Target account role ARN to configure in the Prowler App provider."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Target account role name."
  value       = aws_iam_role.this.name
}
