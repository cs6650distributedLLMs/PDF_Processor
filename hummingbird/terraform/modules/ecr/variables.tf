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

variable "docker_build_context" {
  description = "Path to the directory containing the Dockerfile"
  type        = string
  default     = "../src"
}

variable "image_tag" {
  description = "Tag to apply to the Docker image"
  type        = string
  default     = "latest"
}
