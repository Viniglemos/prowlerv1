output "bucket_name" {
  description = "Nome do bucket S3 criado para backend Terraform da conta management."
  value       = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  description = "ARN do bucket S3 criado para backend Terraform da conta management."
  value       = aws_s3_bucket.this.arn
}

