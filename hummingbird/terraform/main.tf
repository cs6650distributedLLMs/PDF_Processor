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

locals {
  common_tags = {
    Scope = "mscs"
    App   = "hummingbird"
    Class = "CS7990"
  }
}

module "media_bucket" {
  source          = "./modules/media-bucket"
  additional_tags = local.common_tags
}

module "ecr" {
  source          = "./modules/ecr"
  additional_tags = local.common_tags
}

module "app" {
  depends_on      = [module.ecr]
  source          = "./modules/app"
  additional_tags = local.common_tags
  image_uri       = module.ecr.image_uri
}

module "eventing" {
  depends_on      = [module.ecr]
  source          = "./modules/eventing"
  additional_tags = local.common_tags
}
