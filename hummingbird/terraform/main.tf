terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.84"
    }
  }

  backend "s3" {
    bucket         = "terraform-state-bucket"
    key            = "hummingbird/terraform.tfstate"
    region         = "ca-central-1"
    dynamodb_table = "terraform-state-lock-table"
    encrypt        = true
  }
}
