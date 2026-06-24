output "stack_set_name" {
  description = "Nome do StackSet."
  value       = aws_cloudformation_stack_set.this.name
}

output "role_name" {
  description = "Nome da role criada nas contas alvo."
  value       = "${{ values.roleName }}"
}

