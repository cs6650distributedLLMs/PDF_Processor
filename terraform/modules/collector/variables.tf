variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "aws_region" {
  description = "The AWS region to deploy resources."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "IP CIDR block of the VPC"
  type        = string
}

variable "otel_http_port" {
  description = "Port the application listens on"
  type        = number
}

variable "otel_col_health_port" {
  description = "Port the collector health check listens on"
  type        = number
  default     = 13133
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  type        = string
}

variable "gateway_image_uri" {
  description = "URI of the Docker image to run"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs of the public subnets"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "IDs of the private subnets"
  type        = list(string)
}

variable "grafana_api_key_secret_arn" {
  description = "ARN of the secret containing the Grafana API key"
  type        = string
}

variable "grafana_otel_endpoint" {
  description = "Endpoint for Grafana OpenTelemetry"
  type        = string
}

variable "grafana_cloud_instance_id" {
  description = "Grafana Cloud instance ID"
  type        = number
}

variable "collector_log_group_name" {
  description = "Name of the CloudWatch log group for the collector"
  type        = string
}

variable "alb_sg_id" {
  description = "ID of the security group for the ALB"
  type        = string
}

variable "container_sg_id" {
  description = "ID of the security group for the container"
  type        = string
}

variable "desired_task_count" {
  description = "Initial number of tasks to run"
  type        = number
}
