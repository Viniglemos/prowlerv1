variable "aws_region" {
  description = "AWS region used by the provider for IAM API calls."
  type        = string
  default     = "us-east-1"
}

variable "role_name" {
  description = "Name of the cross-account role Prowler assumes in target accounts."
  type        = string
  default     = "ProwlerAuditRole"

  validation {
    condition     = var.role_name == "ProwlerAuditRole"
    error_message = "The MVP role name must remain ProwlerAuditRole unless the project scope is explicitly changed."
  }
}

variable "trusted_principal_arn" {
  description = "ARN of the management/security account role or principal allowed to assume this audit role."
  type        = string

  validation {
    condition     = can(regex("^arn:aws(-[a-z]+)?:iam::[0-9]{12}:((role|user)/.+|root)$", var.trusted_principal_arn))
    error_message = "trusted_principal_arn must be an IAM principal ARN, such as arn:aws:iam::123456789012:role/ProwlerPipelineRole."
  }
}

variable "external_id" {
  description = "Optional ExternalId required when the trusted principal assumes this role."
  type        = string
  default     = ""
}

variable "max_session_duration" {
  description = "Maximum role session duration in seconds."
  type        = number
  default     = 14400

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "max_session_duration must be between 3600 and 43200 seconds."
  }
}

variable "tags" {
  description = "Tags to apply to the Prowler audit role."
  type        = map(string)
  default = {
    Project = "prowler-aws-security-audit"
    Managed = "terraform"
  }
}
