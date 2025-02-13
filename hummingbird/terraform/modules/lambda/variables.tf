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
