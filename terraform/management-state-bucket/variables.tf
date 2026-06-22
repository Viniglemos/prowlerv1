variable "aws_region" {
  description = "Regiao AWS usada pelo provider."
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Nome do bucket S3 usado como backend Terraform da conta management."
  type        = string
}

variable "tags" {
  description = "Tags opcionais aplicadas ao bucket."
  type        = map(string)
  default     = {}
}
