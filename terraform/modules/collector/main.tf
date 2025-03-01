resource "aws_security_group" "alb_security_group" {
  name        = "hummingbird-collector-alb-security-group"
  description = "controls access to the ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTP traffic from the OTel exporters"
    protocol    = "tcp"
    from_port   = var.otel_http_port
    to_port     = var.otel_http_port
    cidr_blocks = var.private_subnet_cidrs
  }

  egress {
    description = "Allow all outbound traffic"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.additional_tags, {
    Name = "hummingbird-collector-alb-security-group"
  })
}

resource "aws_alb" "alb" {
  name    = "hummingbird-collector-alb"
  subnets = var.private_subnet_ids
  security_groups = [
    aws_security_group.alb_security_group.id
  ]

  tags = merge(var.additional_tags, {
    Name = "hummingbird-collector-alb"
  })
}

resource "aws_alb_target_group" "alb_target_group" {
  name        = "hummingbird-collector-alb-tg"
  port        = var.otel_http_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  # TODO: Explore Otel health check

  tags = merge(var.additional_tags, {
    Name = "hummingbird-collector-alb-tg"
  })
}

resource "aws_alb_listener" "alb_listener" {
  load_balancer_arn = aws_alb.alb.arn
  port              = var.otel_http_port
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.alb_target_group.arn
    type             = "forward"
  }

  depends_on = [aws_alb_target_group.alb_target_group]

  tags = merge(var.additional_tags, {
    Name = "hummingbird-collector-alb-listener"
  })
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "hummingbird-collector-ecs-cluster"

  tags = merge(var.additional_tags, {
    Name = "hummingbird-collector-ecs-cluster"
  })
}

resource "aws_security_group" "container_security_group" {
  description = "Access to the Fargate containers"
  vpc_id      = var.vpc_id

  ingress {
    protocol  = "tcp"
    from_port = var.otel_http_port
    to_port   = var.otel_http_port
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
    Name = "hummingbird-collector-container-security-group"
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
  name               = "hummingbird-collector-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json
  path               = "/"

  tags = merge(var.additional_tags, {
    Name = "hummingbird-collector-ecs-task-role"
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
    sid    = "SecretsManager"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [var.grafana_api_key_secret_arn]
  }
}

resource "aws_iam_role_policy" "ecs_role_policy" {
  name   = "hummingbird-collector-ecs-tasks-iam-role-policy"
  role   = aws_iam_role.ecs_task_role.id
  policy = data.aws_iam_policy_document.ecs_iam_role_policy.json
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "hummingbird-collector-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json

  tags = merge(var.additional_tags, {
    Name = "hummingbird-collector-ecs-task-execution-role"
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "ecs_task_definition" {
  family                   = "hummingbird-otel-collector"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  requires_compatibilities = ["FARGATE"]

  container_definitions = <<TASK_DEFINITION
  [
    {
      "name": "otel-gateway-collector",
      "image": "${var.gateway_image_uri}",
      "essential": true,
      "environment": [
        {
          "name": "GRAFANA_OTEL_ENDPOINT",
          "value": "${var.grafana_otel_endpoint}"
        },
        {
          "name": "GRAFANA_CLOUD_INSTANCE_ID",
          "value": "${var.grafana_cloud_instance_id}"
        }
      ],
      "secrets": [
        {
          "name": "GRAFANA_CLOUD_API_KEY",
          "valueFrom": "${var.grafana_api_key_secret_arn}"
        }
      ],
      "portMappings": [
        {
          "protocol": "tcp",
          "containerPort": ${var.otel_http_port}
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/hummingbird-otel-collector",
          "awslogs-region": "${var.aws_region}",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
  TASK_DEFINITION
  network_mode          = "awsvpc"
  cpu                   = "512"
  memory                = "1024"

  tags = merge(var.additional_tags, {
    Name = "hummingbird-collector-ecs-task-definition"
  })
}

resource "aws_ecs_service" "ecs_service" {
  name            = "hummingbird-collector-ecs-service"
  cluster         = aws_ecs_cluster.ecs_cluster.arn
  task_definition = aws_ecs_task_definition.ecs_task_definition.arn
  launch_type     = "FARGATE"
  desired_count   = 2

  load_balancer {
    target_group_arn = aws_alb_target_group.alb_target_group.arn
    container_name   = "otel-gateway-collector"
    container_port   = var.otel_http_port
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
    Name = "hummingbird-collector-ecs-service"
  })
}
