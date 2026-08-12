terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Local state for this guide (default behavior — block omitted).
  # Uncomment below to switch to a remote S3 backend once the
  # bucket + DynamoDB table exist (see Day-02):
  #
  # backend "s3" {
  #   bucket         = "day01-terraform-state-bucket"
  #   key            = "day-01/ec2-default-vpc/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "day-01-ec2-default-vpc"
      Environment = "learning"
      ManagedBy   = "terraform"
    }
  }
}
