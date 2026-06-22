terraform {
  required_version = ">= 1.9.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.82"
    }
  }

  backend "s3" {
    bucket  = "state-management"
    key     = "prowler-target-role/default.tfstate"
    encrypt = true
    region  = "us-east-1"
    profile = ""
  }
}

provider "aws" {
  region  = var.aws_region
  profile = ""

  assume_role {
    role_arn = "arn:aws:iam::${var.target_account_id}:role/${var.terraform_deployment_role_name}"
  }
}
