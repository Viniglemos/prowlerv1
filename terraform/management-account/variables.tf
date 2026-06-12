variable "aws_region" {
  description = "AWS region used by the provider."
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Name of the private S3 bucket used as the official Prowler report evidence repository."
  type        = string
  default     = "security-audit-prowler-reports"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be a valid S3 bucket name."
  }
}

variable "reports_prefix" {
  description = "Top-level S3 prefix for report uploads."
  type        = string
  default     = "aws"

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9/_-]*[A-Za-z0-9]$|^[A-Za-z0-9]$", var.reports_prefix))
    error_message = "reports_prefix must be a non-empty relative prefix without leading or trailing slashes."
  }
}

variable "pipeline_role_arn" {
  description = "IAM role ARN allowed to write filtered Prowler reports to the bucket."
  type        = string

  validation {
    condition     = can(regex("^arn:aws(-[a-z]+)?:iam::[0-9]{12}:role/.+$", var.pipeline_role_arn))
    error_message = "pipeline_role_arn must be an IAM role ARN, such as arn:aws:iam::123456789012:role/SecurityAuditPipelineRole."
  }
}

variable "report_expiration_days" {
  description = "Number of days to retain current report objects."
  type        = number
  default     = 365

  validation {
    condition     = var.report_expiration_days >= 30
    error_message = "report_expiration_days must be at least 30 days."
  }
}

variable "noncurrent_version_expiration_days" {
  description = "Number of days to retain noncurrent report object versions."
  type        = number
  default     = 90

  validation {
    condition     = var.noncurrent_version_expiration_days >= 30
    error_message = "noncurrent_version_expiration_days must be at least 30 days."
  }
}

variable "force_destroy" {
  description = "Whether Terraform may delete the bucket even when it contains objects."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to S3 report resources."
  type        = map(string)
  default = {
    Project = "prowler-aws-security-audit"
    Managed = "terraform"
  }
}
