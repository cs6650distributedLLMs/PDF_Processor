variable "image_uri" {
  description = "URI of the Docker image to run"
  type        = string
}

variable "app_port" {
  description = "Port the application listens on"
  type        = number
  default     = 9000
}

variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
