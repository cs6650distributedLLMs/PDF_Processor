output "grafana_api_key_secret_arn" {
  value = aws_secretsmanager_secret.grafana_api_key_secret.arn
}
