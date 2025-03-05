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

variable "hummingbird_app_port" {
  description = "Port the application listens on"
  type        = number
}

variable "media_s3_bucket_name" {
  description = "S3 bucket for media files"
  type        = string
}

variable "media_dymamo_table_name" {
  description = "Name of the DynamoDB table for media metadata"
  type        = string
}

variable "grafana_otel_endpoint" {
  description = "Endpoint for Grafana OpenTelemetry"
  type        = string
}

variable "grafana_cloud_instance_id" {
  description = "Grafana Cloud instance ID"
  type        = number
}

variable "grafana_cloud_api_key" {
  description = "API key for Grafana Cloud"
  type        = string
}

variable "otel_collector_env" {
  description = "Environment for the OpenTelemetry collector"
  type        = string
}

variable "otel_exporter_hostame" {
  description = "Hostname of the OpenTelemetry exporter"
  type        = string
}

variable "otel_http_port" {
  description = "Port for OpenTelemetry HTTP endpoint"
  type        = number
}

variable "otel_grpc_port" {
  description = "Port for OpenTelemetry GRPC endpoint"
  type        = number
}

variable "otel_sidecar_http_port" {
  description = "Port for OpenTelemetry HTTP endpoint in the app sidecar"
  type        = number
}

variable "otel_sidecar_grpc_port" {
  description = "Port for OpenTelemetry GRPC endpoint in the app sidecar"
  type        = number
}

variable "desired_task_count" {
  description = "Number of tasks to run"
  type        = number
}
