variable "min_ecs_containers" {
  description = "Minimum number of ECS containers to run"
  type        = number
  default     = 2
}

variable "max_ecs_containers" {
  description = "Maximum number of ECS containers to run"
  type        = number
  default     = 10
}

variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
