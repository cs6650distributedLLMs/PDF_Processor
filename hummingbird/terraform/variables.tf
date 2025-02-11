variable "node_env" {
  description = "Node.js environment"
  type        = string
  default     = "development"
}

variable "aws_region" {
  description = "The AWS region to deploy resources."
  type        = string
  default     = "us-west-2"
}

variable "media_s3_bucket_name" {
  description = "S3 bucket for media files"
  type        = string
  default     = "hummingbird-app-media-bucket"
}
