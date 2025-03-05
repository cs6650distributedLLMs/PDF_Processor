terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.84"
    }
  }

  backend "s3" {
    region         = "us-west-2"
    bucket         = "hummingbird-terraform-state-bucket"
    key            = "hummingbird/terraform.tfstate"
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
  vpc_cidr             = "10.0.0.0/24"
  public_subnet_cidrs  = ["10.0.0.0/26", "10.0.0.64/26"]
  private_subnet_cidrs = ["10.0.0.128/26", "10.0.0.192/26"]
}

module "networking" {
  source               = "./modules/networking"
  additional_tags      = local.common_tags
  vpc_cidr             = local.vpc_cidr
  public_subnet_cidrs  = local.public_subnet_cidrs
  private_subnet_cidrs = local.private_subnet_cidrs
}

module "media_bucket" {
  source               = "./modules/media-bucket"
  additional_tags      = local.common_tags
  media_s3_bucket_name = var.media_s3_bucket_name
}

module "ecr" {
  source          = "./modules/ecr"
  additional_tags = local.common_tags
}

module "hummingbird_docker" {
  source               = "./modules/docker"
  docker_build_context = "../hummingbird/app"
  image_tag_prefix     = "hummingbird"
  ecr_repository_url   = module.ecr.repository_url
}

module "otel_sidecar_docker" {
  source               = "./modules/docker"
  docker_build_context = "../collector/sidecar"
  image_tag_prefix     = "sidecar"
  ecr_repository_url   = module.ecr.repository_url
}

module "otel_gateway_docker" {
  source               = "./modules/docker"
  docker_build_context = "../collector/gateway"
  image_tag_prefix     = "gateway"
  ecr_repository_url   = module.ecr.repository_url
}

module "cw_hummingbird_app" {
  source          = "./modules/cloudwatch"
  additional_tags = local.common_tags
  log_group_name  = "hummingbird-app"
}

module "cw_hummingbird_sidecar" {
  source          = "./modules/cloudwatch"
  additional_tags = local.common_tags
  log_group_name  = "hummingbird-sidecar"
}

module "cw_hummingbird_collector" {
  source          = "./modules/cloudwatch"
  additional_tags = local.common_tags
  log_group_name  = "hummingbird-collector"
}

module "collector_gateway_alb_sg" {
  source          = "./modules/security-group"
  additional_tags = local.common_tags
  vpc_id          = module.networking.vpc_id
  name_prefix     = "collector-alb-sg"
  description     = "OTel collector gateway ALB security group"
}

module "collector_gateway_container_sg" {
  source          = "./modules/security-group"
  additional_tags = local.common_tags
  vpc_id          = module.networking.vpc_id
  name_prefix     = "collector-container-sg"
  description     = "OTel collector gateway container security group"
}

module "app_alb_sg" {
  source          = "./modules/security-group"
  additional_tags = local.common_tags
  vpc_id          = module.networking.vpc_id
  name_prefix     = "app-alb-sg"
  description     = "Hummingbird app ALB security group"
}

module "app_container_sg" {
  source          = "./modules/security-group"
  additional_tags = local.common_tags
  vpc_id          = module.networking.vpc_id
  name_prefix     = "app-container-sg"
  description     = "Hummingbird app container security group"
}

module "dynamodb" {
  depends_on = [module.networking]

  source                  = "./modules/dynamodb"
  additional_tags         = local.common_tags
  aws_region              = var.aws_region
  vpc_id                  = module.networking.vpc_id
  dynamodb_table_name     = var.media_dymamo_table_name
  private_route_table_ids = module.networking.private_route_table_ids
}

module "eventing" {
  depends_on = [module.ecr]

  source          = "./modules/eventing"
  additional_tags = local.common_tags
}

module "secrets" {
  source                = "./modules/secrets"
  additional_tags       = local.common_tags
  grafana_cloud_api_key = var.grafana_cloud_api_key
}

module "collector" {
  depends_on = [
    module.ecr,
    module.networking,
    module.secrets
  ]

  source = "./modules/collector"

  vpc_id = module.networking.vpc_id

  additional_tags = local.common_tags
  aws_region      = var.aws_region

  desired_task_count = var.desired_task_count

  ecr_repository_arn         = module.ecr.ecr_repository_arn
  gateway_image_uri          = module.otel_gateway_docker.image_uri
  grafana_api_key_secret_arn = module.secrets.grafana_api_key_secret_arn
  grafana_cloud_instance_id  = var.grafana_cloud_instance_id
  grafana_otel_endpoint      = var.grafana_otel_endpoint
  otel_grpc_port             = var.otel_grpc_port
  otel_http_port             = var.otel_http_port

  alb_sg_id          = module.collector_gateway_alb_sg.id
  container_sg_id    = module.collector_gateway_container_sg.id
  private_subnet_ids = module.networking.private_subnet_ids
  public_subnet_ids  = module.networking.public_subnet_ids

  collector_log_group_name = module.cw_hummingbird_collector.log_group_name
}

module "app" {
  depends_on = [
    module.dynamodb,
    module.ecr,
    module.media_bucket,
    module.networking,
    module.collector
  ]

  source = "./modules/app"

  vpc_id          = module.networking.vpc_id
  additional_tags = local.common_tags
  aws_region      = var.aws_region

  desired_task_count = var.desired_task_count

  app_port                   = var.hummingbird_app_port
  dynamodb_table_arn         = module.dynamodb.dynamodb_table_arn
  dynamodb_table_name        = module.dynamodb.dynamodb_table_name
  ecr_repository_arn         = module.ecr.ecr_repository_arn
  hummingbird_image_uri      = module.hummingbird_docker.image_uri
  media_bucket_arn           = module.media_bucket.media_bucket_arn
  media_management_topic_arn = module.eventing.media_management_topic_arn
  media_s3_bucket_name       = var.media_s3_bucket_name
  node_env                   = var.node_env
  otel_collector_env         = var.otel_collector_env
  otel_exporter_hostame      = var.otel_exporter_hostame
  otel_grpc_gateway_endpoint = var.otel_collector_env == "localstack" ? "http://${var.otel_exporter_hostame}:${var.otel_grpc_port}" : "http://${module.collector.alb_dns_name}:${var.otel_grpc_port}"
  otel_http_gateway_endpoint = var.otel_collector_env == "localstack" ? "http://${var.otel_exporter_hostame}:${var.otel_http_port}" : "http://${module.collector.alb_dns_name}:${var.otel_http_port}"
  otel_sidecar_image_uri     = module.otel_sidecar_docker.image_uri
  otel_sidecar_grpc_port     = var.otel_sidecar_grpc_port
  otel_sidecar_http_port     = var.otel_sidecar_http_port

  alb_sg_id          = module.app_alb_sg.id
  container_sg_id    = module.app_container_sg.id
  private_subnet_ids = module.networking.private_subnet_ids
  public_subnet_ids  = module.networking.public_subnet_ids

  app_log_group_name     = module.cw_hummingbird_app.log_group_name
  sidecar_log_group_name = module.cw_hummingbird_sidecar.log_group_name
}

module "lambdas" {
  depends_on = [
    module.dynamodb,
    module.media_bucket,
    module.networking,
    module.collector
  ]

  source = "./modules/lambda"

  lambdas_src_path = "../hummingbird/lambdas"
  additional_tags  = local.common_tags

  dynamodb_table_arn             = module.dynamodb.dynamodb_table_arn
  dynamodb_table_name            = module.dynamodb.dynamodb_table_name
  media_bucket_arn               = module.media_bucket.media_bucket_arn
  media_bucket_id                = module.media_bucket.media_bucket_id
  media_management_sqs_queue_arn = module.eventing.media_management_sqs_queue_arn
  media_s3_bucket_name           = var.media_s3_bucket_name
  otel_http_gateway_endpoint     = var.otel_collector_env == "localstack" ? "http://${var.otel_exporter_hostame}:${var.otel_http_port}" : "http://${module.collector.alb_dns_name}:${var.otel_http_port}"
}
