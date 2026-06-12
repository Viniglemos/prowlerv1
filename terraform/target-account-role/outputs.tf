output "role_name" {
  description = "Name of the Prowler audit role."
  value       = aws_iam_role.prowler_audit.name
}

output "role_arn" {
  description = "ARN of the Prowler audit role."
  value       = aws_iam_role.prowler_audit.arn
}
