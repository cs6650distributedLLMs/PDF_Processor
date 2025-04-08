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

variable "otel_lambda_grpc_port" {
  description = "gRPC port the OpenTelemetry collector the Lambda ADOT collector listens on"
  type        = number
}

variable "otel_lambda_http_port" {
  description = "HTTP port the OpenTelemetry collector the Lambda ADOT collector listens on"
  type        = number
}

variable "otel_grpc_gateway_endpoint" {
  description = "OpenTelemetry gRPC Gateway endpoint"
  type        = string
}

variable "otel_http_gateway_endpoint" {
  description = "OpenTelemetry HTTP Gateway endpoint"
  type        = string
}

variable "opentelemetry_collector_config_file" {
  description = "Path to the OpenTelemetry collector configuration file"
  type        = string
}

variable "process_media_lambda_sg" {
  description = "Security group for the process media lambda"
  type        = string
}

variable "manage_media_lambda_sg" {
  description = "Security group for the manage media lambda"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs of the private subnets"
  type        = list(string)
}

variable "xai_api_key" {
  description = "API key for the XAI service"
  type        = string
}

variable "media_management_topic_arn" {
  description = "ARN of the SNS topic for media management"
  type        = string
}
