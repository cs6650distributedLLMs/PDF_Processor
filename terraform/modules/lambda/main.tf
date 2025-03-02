data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "lambda_iam_policy_document" {
  statement {
    sid    = "EC2Networking"
    effect = "Allow"
    actions = [
      "ec2:AttachNetworkInterface",
      "ec2:CreateNetworkInterface",
      "ec2:CreateNetworkInterfacePermission",
      "ec2:DeleteNetworkInterface",
      "ec2:DeleteNetworkInterfacePermission",
      "ec2:Describe*",
      "ec2:DetachNetworkInterface"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    sid    = "S3"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
      "s3:DeleteObject"
    ]
    resources = [
      var.media_bucket_arn,
      "${var.media_bucket_arn}/*"
    ]
  }

  statement {
    sid    = "DynamoDB"
    effect = "Allow"
    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:DeleteItem",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:UpdateItem"
    ]
    resources = [var.dynamodb_table_arn]
  }

  statement {
    sid    = "SQS"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [var.media_management_sqs_queue_arn]
  }
}

resource "aws_iam_policy" "lambda_iam_policy" {
  name        = "hummigbird-lambda-policy"
  path        = "/"
  description = "IAM policy for Hummingbird lambda functions"
  policy      = data.aws_iam_policy_document.lambda_iam_policy_document.json

  tags = merge(
    var.additional_tags,
    {
      Name = "hummigbird-lambda-policy"
    }
  )
}

#######################
# Build lambda bundle #
#######################
locals {
  files_to_hash = setsubtract(
    fileset(var.lambdas_src_path, "**/*"),
    fileset(var.lambdas_src_path, "node_modules/**/*")
  )
  file_hashes = {
    for file in local.files_to_hash :
    file => filesha256("${var.lambdas_src_path}/${file}")
  }
  combined_hash_input   = join("", values(local.file_hashes))
  source_directory_hash = sha256(local.combined_hash_input)
  lambda_zip_file       = "lambda-functions-payload.zip"
}

resource "null_resource" "build_lambda_bundle" {
  provisioner "local-exec" {
    command     = "npm run build"
    working_dir = var.lambdas_src_path
  }

  triggers = {
    should_trigger_resource = local.source_directory_hash
  }
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${var.lambdas_src_path}/dist/"
  output_path = local.lambda_zip_file

  depends_on = [null_resource.build_lambda_bundle]
}

#######################################
# Build lambda layer for sharp module #
#######################################
resource "null_resource" "build_sharp_lambda_layer" {
  provisioner "local-exec" {
    command     = "sh build-lambda-layer.sh"
    working_dir = "${var.lambdas_src_path}/sharp-layer"
  }

  triggers = {
    should_trigger_resource = local.source_directory_hash
  }
}

locals {
  layer_content_hash = filesha256("${var.lambdas_src_path}/sharp-layer/layer-content.zip")
}

resource "aws_lambda_layer_version" "sharp_lambda_layer" {
  depends_on          = [null_resource.build_sharp_lambda_layer]
  filename            = "${var.lambdas_src_path}/sharp-layer/layer-content.zip"
  layer_name          = "humminbird-sharp-lambda-layer"
  compatible_runtimes = ["nodejs22.x"]
  source_code_hash    = local.layer_content_hash
}

########################
# Delete Media Lambda #
########################
resource "aws_iam_role" "delete_media_iam_role" {
  name               = "hummingbird-delete-media-iam-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = merge(
    var.additional_tags,
    {
      Name = "hummingbird-delete-media-iam-role"
    }
  )
}

resource "aws_lambda_function" "delete_media" {
  depends_on = [aws_lambda_layer_version.sharp_lambda_layer]
  layers     = [aws_lambda_layer_version.sharp_lambda_layer.arn]

  filename         = local.lambda_zip_file
  function_name    = "hummingbird-delete-media-handler"
  role             = aws_iam_role.delete_media_iam_role.arn
  handler          = "index.handlers.deleteMedia"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime          = "nodejs22.x"
  architectures    = [var.lambda_architecture]
  timeout          = 10

  environment {
    variables = {
      MEDIA_BUCKET_NAME           = var.media_s3_bucket_name
      MEDIA_DYNAMODB_TABLE_NAME   = var.dynamodb_table_name
      OTEL_EXPORTER_OTLP_PROTOCOL = "http/protobuf"
    }
  }

  tags = merge(
    var.additional_tags,
    {
      Name = "hummingbird-delete-media-handler"
    }
  )
}

resource "aws_cloudwatch_log_group" "delete_media_cw_log_group" {
  depends_on        = [aws_lambda_function.delete_media]
  name              = "/aws/lambda/${aws_lambda_function.delete_media.function_name}"
  retention_in_days = 7

  tags = merge(
    var.additional_tags,
    {
      Name = "hummingbird-delete-media-handler-log-group"
    }
  )
}

resource "aws_iam_role_policy_attachment" "delete_lambda_iam_policy_policy_attachment" {
  role       = aws_iam_role.delete_media_iam_role.name
  policy_arn = aws_iam_policy.lambda_iam_policy.arn
}

resource "aws_lambda_event_source_mapping" "delete_media_sqs_event_source_mapping" {
  event_source_arn = var.media_management_sqs_queue_arn
  function_name    = aws_lambda_function.delete_media.arn

  tags = merge(
    var.additional_tags,
    {
      Name = "hummingbird-delete-media-sqs-event-source-mapping"
    }
  )
}

########################
# Process Media Lambda #
########################
resource "aws_iam_role" "process_media_iam_role" {
  name               = "hummingbird-process-media-iam-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = merge(
    var.additional_tags,
    {
      Name = "hummingbird-process-media-iam-role"
    }
  )
}

resource "aws_lambda_function" "process_media" {
  depends_on = [aws_lambda_layer_version.sharp_lambda_layer]
  layers     = [aws_lambda_layer_version.sharp_lambda_layer.arn]

  filename         = local.lambda_zip_file
  function_name    = "hummingbird-process-media-handler"
  role             = aws_iam_role.process_media_iam_role.arn
  handler          = "index.handlers.processMedia"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime          = "nodejs22.x"
  timeout          = 30

  # By having 1769 MB of memory, the function will be able to use 1 vCPU
  # https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html#compute-and-storage
  memory_size = 1769

  environment {
    variables = {
      MEDIA_BUCKET_NAME           = var.media_s3_bucket_name
      MEDIA_DYNAMODB_TABLE_NAME   = var.dynamodb_table_name
      OTEL_EXPORTER_OTLP_PROTOCOL = "http/protobuf"
    }
  }

  tags = merge(
    var.additional_tags,
    {
      Name = "hummingbird-process-media-handler"
    }
  )
}

resource "aws_cloudwatch_log_group" "process_media_cw_log_group" {
  depends_on        = [aws_lambda_function.process_media]
  name              = "/aws/lambda/${aws_lambda_function.process_media.function_name}"
  retention_in_days = 7

  tags = merge(
    var.additional_tags,
    {
      Name = "hummingbird-process-media-handler-log-group"
    }
  )
}

resource "aws_iam_role_policy_attachment" "process_lambda_iam_policy_policy_attachment" {
  role       = aws_iam_role.process_media_iam_role.name
  policy_arn = aws_iam_policy.lambda_iam_policy.arn
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_media.arn
  principal     = "s3.amazonaws.com"
  source_arn    = var.media_bucket_arn
}

resource "aws_s3_bucket_notification" "media_bucket_notification" {
  bucket = var.media_bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.process_media.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}
