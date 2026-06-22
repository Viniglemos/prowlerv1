output "stack_set_name" {
  description = "Nome do StackSet que cria a ProwlerScanRole nas contas alvo."
  value       = aws_cloudformation_stack_set.this.name
}

output "deployment_organizational_unit_ids" {
  description = "OUs ou root IDs onde o StackSet foi aplicado."
  value       = local.deployment_organizational_unit_ids
}

output "role_name" {
  description = "Nome da role criada nas contas alvo."
  value       = var.role_name
}

output "management_account_role_arn" {
  description = "ARN da ProwlerScanRole criada na management account."
  value       = var.create_management_account_role ? aws_iam_role.management_account[0].arn : null
}
