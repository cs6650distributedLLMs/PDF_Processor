variable "media_s3_bucket" {
  description = "S3 bucket for media files"
  type        = string
  default     = "media"
}

variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
