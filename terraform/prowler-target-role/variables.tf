variable "aws_region" {
  description = "AWS region used by the provider."
  type        = string
  default     = "us-east-1"
}

variable "role_name" {
  description = "IAM role name created in target AWS accounts for Prowler scans."
  type        = string
  default     = "ProwlerScanRole"
}

variable "target_account_id" {
  description = "ID da conta AWS alvo onde a ProwlerScanRole sera criada."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.target_account_id))
    error_message = "target_account_id deve conter exatamente 12 digitos."
  }
}

variable "terraform_deployment_role_name" {
  description = "Nome da role corporativa assumida pela pipeline Terraform na conta alvo."
  type        = string
  default     = "OrgTerraformDeploymentRole"
}

variable "trusted_irsa_role_arn" {
  description = "IRSA role ARN from the EKS account that is allowed to assume this target role."
  type        = string
}

variable "external_id" {
  description = "Optional external ID required by the target role trust policy."
  type        = string
  default     = ""
  sensitive   = true
}

variable "max_session_duration" {
  description = "Maximum role session duration in seconds for long Prowler scans. Default is 4 hours."
  type        = number
  default     = 14400

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "max_session_duration must be between 3600 and 43200 seconds."
  }
}

variable "tags" {
  description = "Tags applied to IAM resources."
  type        = map(string)
  default     = {}
}
