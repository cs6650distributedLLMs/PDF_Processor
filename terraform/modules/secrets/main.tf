resource "aws_secretsmanager_secret" "grafana_api_key_secret" {
  name        = "hummingbird-grafana-api-key"
  description = "API key for Grafana Cloud"

  tags = merge(var.additional_tags, {
    Name = "hummingbird-grafana-api-key-secret"
  })
}

resource "aws_secretsmanager_secret_version" "grafana_api_key_secret_version" {
  secret_id     = aws_secretsmanager_secret.grafana_api_key_secret.id
  secret_string = var.grafana_cloud_api_key
}
