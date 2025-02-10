terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.84"
    }
  }

  backend "s3" {
    bucket         = "hummingbird-terraform-state-bucket"
    key            = "hummingbird/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "hummingbird-terraform-state-lock-table"
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

module "cloudwatch" {
  source          = "./modules/cloudwatch"
  additional_tags = local.common_tags
}

module "dynamodb" {
  source          = "./modules/dynamodb"
  additional_tags = local.common_tags
}

module "app" {
  depends_on = [
    module.media_bucket,
    module.ecr,
    module.cloudwatch,
    module.dynamodb
  ]

  source              = "./modules/app"
  additional_tags     = local.common_tags
  dynamodb_table_arn  = module.dynamodb.dynamodb_table_arn
  dynamodb_table_name = module.dynamodb.dynamodb_table_name
  ecr_repository_arn  = module.ecr.ecr_repository_arn
  image_uri           = module.ecr.image_uri
  media_bucket_arn    = module.media_bucket.media_bucket_arn
  node_env            = var.node_env
}

module "eventing" {
  depends_on = [module.ecr]

  source          = "./modules/eventing"
  additional_tags = local.common_tags
}
