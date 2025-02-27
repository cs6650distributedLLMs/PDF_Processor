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

variable "otel_http_port" {
  description = "Port the application listens on"
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

variable "private_subnet_ids" {
  description = "IDs of the private subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets"
  type        = list(string)
}
