# This file creates S3 and DynamoDB for storing terraform state

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

# S3 Bucket for Terraform State
resource "aws_s3_bucket" "terraform_state" {
  bucket = "aws-3tier-ha-tfstate-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "Terraform State Bucket"
    Environment = "dev"
  }
}

# Enable Versioning
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block Public Access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable Object Lock (for S3 native locking - optional but recommended)
resource "aws_s3_bucket_object_lock_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 1
    }
  }
}

# DynamoDB Table for State Locking
resource "aws_dynamodb_table" "terraform_lock" {
  name           = "aws-3tier-ha-tfstate-lock"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform State Lock Table"
    Environment = "dev"
  }
}

# Data source to get AWS account ID
data "aws_caller_identity" "current" {}

# Outputs
output "s3_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_lock.name
}
