terraform {
  backend "s3" {
    bucket         = "aws-3tier-ha-tfstate-712111072557"
    key            = "dev/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "aws-3tier-ha-tfstate-lock"
  }
}
