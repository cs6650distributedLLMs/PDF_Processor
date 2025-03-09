variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "otel_collector_env" {
  description = "Environment for the OpenTelemetry collector"
  type        = string
}

variable "otel_gateway_http_port" {
  description = "Collector's HTTP port."
  type        = number
}

variable "otel_gateway_grpc_port" {
  description = "Collector's gRPC port."
  type        = number
}

variable "otel_gateway_health_port" {
  description = "Port for OpenTelemetry Gateway health check"
  type        = number
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

variable "nat_gateway_one_ipv4" {
  description = "IPv4 address of the NAT gateway #1"
  type        = string
}

variable "nat_gateway_two_ipv4" {
  description = "IPv4 address of the NAT gateway #2"
  type        = string
}
