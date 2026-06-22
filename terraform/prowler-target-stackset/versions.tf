terraform {
  required_version = ">= 1.9.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 6.0"
    }
  }

  backend "s3" {
    bucket  = "replace-with-management-state-bucket"
    key     = "prowler-target-stackset.tfstate"
    encrypt = true
    region  = "us-east-1"
    profile = ""
  }
}

provider "aws" {
  region  = var.aws_region
  profile = ""
}
