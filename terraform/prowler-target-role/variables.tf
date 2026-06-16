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

variable "attach_view_only_access" {
  description = "Attach AWS managed ViewOnlyAccess policy in addition to SecurityAudit."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to IAM resources."
  type        = map(string)
  default     = {}
}
