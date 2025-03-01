variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "grafana_cloud_api_key" {
  description = "API key for Grafana Cloud"
  type        = string
}
