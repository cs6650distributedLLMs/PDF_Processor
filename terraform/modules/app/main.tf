resource "aws_security_group" "alb_security_group" {
  name        = "hummingbird-alb-security-group"
  description = "controls access to the ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTP traffic from the internet"
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.additional_tags, {
    Name = "hummingbird-alb-security-group"
  })
}

resource "aws_alb" "alb" {
  name    = "hummingbird-alb"
  subnets = var.public_subnet_ids
  security_groups = [
    aws_security_group.alb_security_group.id
  ]

  tags = merge(var.additional_tags, {
    Name = "hummingbird-alb"
  })
}

resource "aws_alb_target_group" "alb_target_group" {
  name        = "hummingbird-alb-target-group"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    protocol = "HTTP"
    port     = var.app_port
    path     = "/health"

    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }


  tags = merge(var.additional_tags, {
    Name = "hummingbird-alb-target-group"
  })
}

resource "aws_alb_listener" "alb_listener" {
  load_balancer_arn = aws_alb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.alb_target_group.arn
    type             = "forward"
  }

  depends_on = [aws_alb_target_group.alb_target_group]

  tags = merge(var.additional_tags, {
    Name = "hummingbird-alb-listener"
  })
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "hummingbird-ecs-cluster"

  tags = merge(var.additional_tags, {
    Name = "hummingbird-ecs-cluster"
  })
}

resource "aws_security_group" "container_security_group" {
  description = "Access to the Fargate containers"
  vpc_id      = var.vpc_id

  ingress {
    protocol  = "tcp"
    from_port = var.app_port
    to_port   = var.app_port
    security_groups = [
      aws_security_group.alb_security_group.id
    ]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.additional_tags, {
    Name = "hummingbird-container-security-group"
  })
}

data "aws_iam_policy_document" "ecs_assume_role_policy" {
  statement {
    sid     = "ECSAssumeRolePolicy"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_role" {
  name               = "hummingbird-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json
  path               = "/"

  tags = merge(var.additional_tags, {
    Name = "hummingbird-ecs-task-role"
  })
}

data "aws_iam_policy_document" "ecs_iam_role_policy" {
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
    sid    = "ECR"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetAuthorizationToken",
      "ecr:GetDownloadUrlForLayer"
    ]
    resources = [var.ecr_repository_arn]
  }

  statement {
    sid    = "S3"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket"
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
    sid    = "SNS"
    effect = "Allow"
    actions = [
      "sns:Publish"
    ]
    resources = [var.media_management_topic_arn]
  }
}

resource "aws_iam_role_policy" "ecs_role_policy" {
  name   = "hummingbird-ecs-tasks-iam-role-policy"
  role   = aws_iam_role.ecs_task_role.id
  policy = data.aws_iam_policy_document.ecs_iam_role_policy.json
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "hummingbird-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json

  tags = merge(var.additional_tags, {
    Name = "hummingbird-ecs-task-execution-role"
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "ecs_task_definition" {
  family                   = "hummingbird"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  requires_compatibilities = ["FARGATE"]

  container_definitions = <<TASK_DEFINITION
  [
    {
      "name": "hummingbird",
      "image": "${var.hummingbird_image_uri}",
      "essential": true,
      "environment": [
        {"name": "APP_PORT", "value": "${var.app_port}"},
        {"name": "HUMMINGBIRD_DYNAMO_TABLE", "value": "${var.dynamodb_table_name}"},
        {"name": "MEDIA_BUCKET_NAME", "value": "${var.media_s3_bucket_name}"},
        {"name": "MEDIA_MANAGEMENT_TOPIC_ARN", "value": "${var.media_management_topic_arn}"},
        {"name": "MEDIA_DYNAMODB_TABLE_NAME", "value": "${var.dynamodb_table_name}"},
        {"name": "NODE_ENV", "value": "${var.node_env}"}
      ],
      "portMappings": [
        {
          "protocol": "tcp",
          "containerPort": ${var.app_port}
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/hummingbird",
          "awslogs-region": "${var.aws_region}",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "dependsOn": [
        {
          "containerName": "adot-sidecar-collector",
          "condition": "START"
        }
      ]
    },
    {
      "name": "adot-sidecar-collector",
      "image": "${var.otel_sidecar_image_uri}",
      "cpu": 256,
      "memory": 512,
      "essential": true,
      "environment": [
        {
          "name": "OTEL_GATEWAY_HTTP_ENDPOINT",
          "value": "REPLACE_ME"
        }
      ],
      "portMappings": [
        {
          "protocol": "tcp",
          "hostPort": 4318,
          "containerPort": 4318
        },
        {
          "protocol": "tcp",
          "hostPort": 4317,
          "containerPort": 4317
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/hummingbird-otel-sidecar",
          "awslogs-region": "${var.aws_region}",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
  TASK_DEFINITION
  network_mode          = "awsvpc"
  cpu                   = "1024"
  memory                = "3072"

  tags = merge(var.additional_tags, {
    Name = "hummingbird-ecs-task-definition"
  })
}

resource "aws_ecs_service" "ecs_service" {
  name            = "hummingbird-ecs-service"
  cluster         = aws_ecs_cluster.ecs_cluster.arn
  task_definition = aws_ecs_task_definition.ecs_task_definition.arn
  launch_type     = "FARGATE"
  desired_count   = 2

  load_balancer {
    target_group_arn = aws_alb_target_group.alb_target_group.arn
    container_name   = "hummingbird"
    container_port   = var.app_port
  }

  network_configuration {
    assign_public_ip = false
    subnets          = var.private_subnet_ids
    security_groups = [
      aws_security_group.container_security_group.id
    ]
  }

  depends_on = [
    aws_ecs_cluster.ecs_cluster,
    aws_ecs_task_definition.ecs_task_definition,
    aws_alb_target_group.alb_target_group
  ]

  tags = merge(var.additional_tags, {
    Name = "hummingbird-ecs-service"
  })
}
