output "bucket_name" {
  description = "Name of the S3 reports bucket."
  value       = aws_s3_bucket.reports.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 reports bucket."
  value       = aws_s3_bucket.reports.arn
}

output "reports_prefix" {
  description = "Top-level prefix for filtered report uploads."
  value       = var.reports_prefix
}

output "reports_s3_uri" {
  description = "Base S3 URI for filtered Prowler reports."
  value       = "s3://${aws_s3_bucket.reports.bucket}/${var.reports_prefix}/"
}
