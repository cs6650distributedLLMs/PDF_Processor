data "aws_caller_identity" "current" {}

resource "aws_sqs_queue" "media_management_sqs_queue" {
  name                      = var.media_mngmt_queue_name
  delay_seconds             = 10
  max_message_size          = 1024 * 5     // 5 KB
  message_retention_seconds = 60 * 60 * 24 // 1 day
  receive_wait_time_seconds = 5
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.media_management_sqs_dlq.arn
    maxReceiveCount     = 5
  })

  tags = merge(var.additional_tags, {
    Name = var.media_mngmt_queue_name
  })
}

resource "aws_sqs_queue" "media_management_sqs_dlq" {
  name = var.media_mngmt_dlq_name

  tags = merge(var.additional_tags, {
    Name = var.media_mngmt_dlq_name
  })
}

resource "aws_sns_topic" "media_management_topic" {
  name = var.media_mngmt_topic_name

  tags = merge(var.additional_tags, {
    Name = var.media_mngmt_topic_name
  })
}

data "aws_iam_policy_document" "sns_topic_policy" {
  policy_id = "__default_policy_ID"

  statement {
    actions = ["sqs:SendMessage"]

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    resources = [
      aws_sqs_queue.media_management_sqs_queue.arn
    ]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.media_management_topic.arn]
    }

    sid = "__default_statement_ID"
  }
}

resource "aws_sns_topic_policy" "sqs_sns_topic_policy" {
  arn    = aws_sns_topic.media_management_topic.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

resource "aws_sns_topic_subscription" "sqs_sns_subscription" {
  topic_arn = aws_sns_topic.media_management_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.media_management_sqs_queue.arn
}
