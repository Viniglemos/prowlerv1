variable "aws_region" {
  description = "Regiao AWS usada pelo provider e pelo StackSet."
  type        = string
  default     = "us-east-1"
}

variable "role_name" {
  description = "Nome da role corporativa criada nas contas da organizacao para execucao de Terraform."
  type        = string
  default     = "OrgTerraformDeploymentRole"
}

variable "trusted_principal_arns" {
  description = "Lista de ARNs IAM autorizados a assumir a role corporativa de Terraform."
  type        = list(string)

  validation {
    condition     = length(var.trusted_principal_arns) > 0
    error_message = "trusted_principal_arns deve conter ao menos um ARN IAM confiavel."
  }
}

variable "organizational_unit_ids" {
  description = "Lista de OUs ou root IDs onde o StackSet sera aplicado. Se vazio, usa o root da organizacao."
  type        = list(string)
  default     = []
}

variable "create_management_account_role" {
  description = "Define se a role tambem sera criada na management account, que nao recebe StackSet service-managed como conta alvo."
  type        = bool
  default     = true
}

variable "max_session_duration" {
  description = "Duracao maxima da sessao da role em segundos."
  type        = number
  default     = 14400

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "max_session_duration deve ficar entre 3600 e 43200 segundos."
  }
}
