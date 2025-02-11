variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "aws_region" {
  description = "The AWS region to deploy resources."
  type        = string
  default     = "us-west-2"
}

variable "app_port" {
  description = "Port the application listens on"
  type        = number
  default     = 9000
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  type        = string
}

variable "image_uri" {
  description = "URI of the Docker image to run"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  type        = string
}

variable "media_bucket_arn" {
  description = "ARN of the S3 bucket for media files"
  type        = string
}

variable "media_management_topic_arn" {
  description = "ARN of the SNS topic for media management"
  type        = string
}

variable "node_env" {
  description = "Node.js environment"
  type        = string
}

variable "media_s3_bucket_name" {
  description = "S3 bucket for media files"
  type        = string
}
