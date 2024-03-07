# Doc AWS Provider: [ https://registry.terraform.io/providers/hashicorp/aws/latest/docs ]

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.39.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}