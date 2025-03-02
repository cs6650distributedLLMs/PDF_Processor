variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  type        = string
}

variable "media_bucket_arn" {
  description = "ARN of the S3 bucket for media files"
  type        = string
}

variable "media_bucket_id" {
  description = "ID of the S3 bucket for media files"
  type        = string
}

variable "media_s3_bucket_name" {
  description = "S3 bucket for media files"
  type        = string
}

variable "media_management_sqs_queue_arn" {
  description = "ARN of the SQS queue for media management"
  type        = string
}

variable "lambdas_src_path" {
  description = "Path to the directory containing the lambda source code"
  type        = string
}

variable "lambda_architecture" {
  description = "Architecture to build the lambda for"
  type        = string
  default     = "x86_64"
}

variable "otel_collector_config_uri" {
  description = "Path to the OpenTelemetry collector configuration file"
  type        = string
}

variable "otel_gateway_endpoint" {
  description = "OpenTelemetry Gateway endpoint"
  type        = string
}

variable "otel_gateway_port" {
  description = "OpenTelemetry Gateway port"
  type        = number
  default     = 4318
}

variable "private_subnet_ids" {
  description = "IDs of the private subnets"
  type        = list(string)
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "process_media_lambda_sg_id" {
  description = "ID of the security group for the media processing lambda"
  type        = string
}

variable "delete_media_lambda_sg_id" {
  description = "ID of the security group for the media deletion lambda"
  type        = string
}
