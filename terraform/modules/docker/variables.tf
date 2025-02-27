variable "aws_region" {
  description = "The AWS region to deploy resources."
  type        = string
  default     = "us-west-2"
}

variable "docker_build_context" {
  description = "Path to the directory containing the Dockerfile"
  type        = string
}

variable "ecr_repository_url" {
  description = "URL of the ECR repository"
  type        = string
}

variable "image_tag_prefix" {
  description = "Prefix to apply to the image tag"
  type        = string
}
