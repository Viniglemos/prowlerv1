variable "aws_region" {
  description = "Regiao AWS usada pelo provider e pelo StackSet."
  type        = string
  default     = "us-east-1"
}

variable "stack_set_name" {
  description = "Nome do StackSet que cria a role de scan do Prowler nas contas alvo."
  type        = string
  default     = "ProwlerScanRole"
}

variable "role_name" {
  description = "Nome da role IAM criada nas contas alvo para scans do Prowler."
  type        = string
  default     = "ProwlerScanRole"
}

variable "trusted_irsa_role_arn" {
  description = "ARN da role IRSA da conta tools autorizada a assumir a ProwlerScanRole nas contas alvo."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/.+", var.trusted_irsa_role_arn))
    error_message = "trusted_irsa_role_arn deve ser um ARN valido de role IAM."
  }
}

variable "organizational_unit_ids" {
  description = "Lista de OUs ou root IDs onde o StackSet sera aplicado. Se vazio, usa o root da organizacao."
  type        = list(string)
  default     = []
}

variable "create_management_account_role" {
  description = "Define se a ProwlerScanRole tambem sera criada na management account."
  type        = bool
  default     = true
}

variable "max_session_duration" {
  description = "Duracao maxima da sessao da role em segundos. Padrao de 4 horas para scans longos."
  type        = number
  default     = 14400

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "max_session_duration deve ficar entre 3600 e 43200 segundos."
  }
}
