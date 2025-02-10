variable "media_s3_bucket" {
  description = "S3 bucket for media files"
  type        = string
  default     = "hummingbird-app-media-bucket"
}

variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
