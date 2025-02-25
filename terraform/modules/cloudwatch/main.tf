resource "aws_cloudwatch_log_group" "cw_log_group" {
  name              = var.log_group_name
  retention_in_days = 7

  tags = merge(var.additional_tags, {
    Name = "hummingbird-cloudwatch-log-group"
  })
}

resource "aws_cloudwatch_log_stream" "cw_log_stream" {
  name           = var.log_stream_name
  log_group_name = aws_cloudwatch_log_group.cw_log_group.name
}
