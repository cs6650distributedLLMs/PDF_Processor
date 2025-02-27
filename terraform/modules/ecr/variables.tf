variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "hummingbird-media-ecr-repository"
}
