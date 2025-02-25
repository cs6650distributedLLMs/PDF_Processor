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

variable "ecr_repository_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "hummingbird-media-ecr-repository"
}

variable "hummingbird_app_docker_build_context" {
  description = "Path to the directory containing the Dockerfile"
  type        = string
}
