resource "aws_vpc_security_group_ingress_rule" "allow_alb_inbound_traffic" {
  security_group_id = var.alb_sg_id
  description       = "Allow HTTP traffic from the OTel exporters"
  from_port         = var.otel_http_port
  to_port           = var.otel_http_port
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "tcp"

  tags = merge(var.additional_tags, {
    Name = "humminbird-collector-allow-inbound-traffic"
  })
}

resource "aws_vpc_security_group_ingress_rule" "allow_inboud_process_media_lambda" {
  security_group_id            = var.alb_sg_id
  description                  = "Allow traffic from the media processing lambda"
  ip_protocol                  = -1
  referenced_security_group_id = var.media_processing_lambda_security_group_id

  tags = merge(var.additional_tags, {
    Name = "collector-lambda-allow-inbound-traffic"
  })
}

resource "aws_vpc_security_group_egress_rule" "allow_alb_outbound_traffic" {
  security_group_id = var.alb_sg_id
  description       = "Allow all outbound traffic"
  from_port         = 0
  to_port           = 0
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"

  tags = merge(var.additional_tags, {
    Name = "humminbird-collector-allow-outbound-traffic"
  })
}

resource "aws_alb" "alb" {
  name            = "hummingbird-collector-alb"
  subnets         = var.private_subnet_ids
  security_groups = [var.alb_sg_id]
  internal        = true

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

resource "aws_vpc_security_group_ingress_rule" "allow_container_inbound_traffic" {
  security_group_id            = var.container_sg_id
  referenced_security_group_id = var.alb_sg_id
  description                  = "Allow HTTP traffic from ALB"
  from_port                    = var.otel_http_port
  to_port                      = var.otel_http_port
  ip_protocol                  = "tcp"

  tags = merge(var.additional_tags, {
    Name = "hummingbird-container-allow-inbound-traffic"
  })
}

resource "aws_vpc_security_group_egress_rule" "allow_container_outboung_traffic" {
  security_group_id = var.container_sg_id
  description       = "Allow all outbound traffic"
  from_port         = 0
  to_port           = 0
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  tags = merge(var.additional_tags, {
    Name = "humminbird-container-allow-outbound-traffic"
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
          "awslogs-group": "${var.collector_log_group_name}",
          "awslogs-region": "${var.aws_region}",
          "awslogs-stream-prefix": "collector"
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
    security_groups  = [var.container_sg_id]
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
