terraform {
  required_version = ">= 1.9.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.82"
    }
  }

  backend "s3" {
    bucket  = "state-tools"
    key     = "prowler-app-irsa.tfstate"
    encrypt = true
    region  = "us-east-1"
    profile = ""
  }
}

provider "aws" {
  region  = var.aws_region
  profile = ""
}
