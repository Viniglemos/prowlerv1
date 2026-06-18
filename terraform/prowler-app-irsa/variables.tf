variable "aws_region" {
  description = "AWS region used by the provider."
  type        = string
  default     = "us-east-1"
}

variable "role_name" {
  description = "IAM role name used by the Prowler App Kubernetes ServiceAccount through IRSA."
  type        = string
  default     = "prowler-app-irsa"
}

variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN."
  type        = string
}

variable "oidc_provider_url" {
  description = "EKS OIDC provider URL without https://."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace where Prowler App runs."
  type        = string
  default     = "security-audit"
}

variable "service_account_name" {
  description = "Kubernetes ServiceAccount used by the Prowler App API and workers."
  type        = string
  default     = "prowler-app"
}

variable "target_role_name" {
  description = "Role name that exists in target AWS accounts and is assumed by the Prowler App IRSA role."
  type        = string
  default     = "ProwlerScanRole"
}

variable "target_account_ids" {
  description = "Target AWS account IDs allowed for sts:AssumeRole. Keep explicit in production."
  type        = list(string)
  default     = []
}

variable "max_session_duration" {
  description = "Maximum IRSA role session duration in seconds. Default is 4 hours."
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
