data "aws_region" "current" {}

resource "aws_vpc_security_group_ingress_rule" "allow_alb_inbound_traffic_grpc_ng1" {
  security_group_id = var.alb_sg_id
  description       = "Allow GRPC traffic from the OTel exporters"
  from_port         = var.otel_gateway_grpc_port
  to_port           = var.otel_gateway_grpc_port
  cidr_ipv4         = var.nat_gateway_one_ipv4
  ip_protocol       = "tcp"

  tags = merge(var.additional_tags, {
    Name = "hummingbird-collector-allow-inbound-traffic-grpc"
  })
}

resource "aws_vpc_security_group_ingress_rule" "allow_alb_inbound_traffic_grpc_ng2" {
  security_group_id = var.alb_sg_id
  description       = "Allow GRPC traffic from the OTel exporters"
  from_port         = var.otel_gateway_grpc_port
  to_port           = var.otel_gateway_grpc_port
  cidr_ipv4         = var.nat_gateway_two_ipv4
  ip_protocol       = "tcp"

  tags = merge(var.additional_tags, {
    Name = "hummingbird-collector-allow-inbound-traffic-grpc"
  })
}

resource "aws_vpc_security_group_ingress_rule" "allow_alb_inbound_traffic_http_ng1" {
  security_group_id = var.alb_sg_id
  description       = "Allow HTTP traffic from the OTel exporters"
  from_port         = var.otel_gateway_http_port
  to_port           = var.otel_gateway_http_port
  cidr_ipv4         = var.nat_gateway_one_ipv4
  ip_protocol       = "tcp"

  tags = merge(var.additional_tags, {
    Name = "hummingbird-collector-allow-inbound-traffic-http"
  })
}

resource "aws_vpc_security_group_ingress_rule" "allow_alb_inbound_traffic_http_ng2" {
  security_group_id = var.alb_sg_id
  description       = "Allow HTTP traffic from the OTel exporters"
  from_port         = var.otel_gateway_http_port
  to_port           = var.otel_gateway_http_port
  cidr_ipv4         = var.nat_gateway_two_ipv4
  ip_protocol       = "tcp"

  tags = merge(var.additional_tags, {
    Name = "hummingbird-collector-allow-inbound-traffic-http"
  })
}

resource "aws_vpc_security_group_egress_rule" "allow_alb_outbound_traffic" {
  security_group_id = var.alb_sg_id
  description       = "Allow all outbound traffic"
  from_port         = 0
  to_port           = 65535
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"

  tags = merge(var.additional_tags, {
    Name = "hummingbird-collector-allow-outbound-traffic"
  })
}

resource "aws_alb" "alb" {
  name            = "hummingbird-collector-alb"
  subnets         = var.public_subnet_ids
  security_groups = [var.alb_sg_id]
  enable_http2    = false

  tags = merge(var.additional_tags, {
    Name = "hummingbird-collector-alb"
  })
}

resource "aws_alb_target_group" "alb_grpc_target_group" {
  name     = "hummingbird-col-alb-grpc-tg"
  port     = var.otel_gateway_grpc_port
  protocol = "HTTP"
  # protocol_version = "GRPC"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    protocol = "HTTP"
    port     = var.otel_gateway_health_port
    path     = "/health"

    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 4
  }

  tags = merge(var.additional_tags, {
    Name = "hummingbird-collector-alb-grpc-tg"
  })
}

resource "aws_alb_listener" "alb_grpc_listener" {
  load_balancer_arn = aws_alb.alb.arn
  port              = var.otel_gateway_grpc_port
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.alb_grpc_target_group.arn
    type             = "forward"

    forward {
      target_group {
        arn = aws_alb_target_group.alb_grpc_target_group.arn
      }
      stickiness {
        enabled  = true
        duration = 3600
      }
    }
  }

  depends_on = [aws_alb_target_group.alb_grpc_target_group]

  tags = merge(var.additional_tags, {
    Name = "hummingbird-collector-alb-grpc-listener"
  })
}

resource "aws_alb_target_group" "alb_http_target_group" {
  name        = "hummingbird-col-alb-http-tg"
  port        = var.otel_gateway_http_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    protocol = "HTTP"
    port     = var.otel_gateway_health_port
    path     = "/health"

    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 4
  }

  tags = merge(var.additional_tags, {
    Name = "hummingbird-collector-alb-http-tg"
  })
}

resource "aws_alb_listener" "alb_http_listener" {
  load_balancer_arn = aws_alb.alb.arn
  port              = var.otel_gateway_http_port
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.alb_http_target_group.arn
    type             = "forward"

    forward {
      target_group {
        arn = aws_alb_target_group.alb_http_target_group.arn
      }
      stickiness {
        enabled  = true
        duration = 3600
      }
    }
  }

  depends_on = [aws_alb_target_group.alb_http_target_group]

  tags = merge(var.additional_tags, {
    Name = "hummingbird-collector-alb-http-listener"
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
  description                  = "Allow HTTP and GRPC traffic from ALB"
  from_port                    = var.otel_gateway_grpc_port
  to_port                      = var.otel_gateway_http_port
  ip_protocol                  = "tcp"

  tags = merge(var.additional_tags, {
    Name = "hummingbird-container-allow-inbound-traffic"
  })
}

resource "aws_vpc_security_group_ingress_rule" "allow_container_inbound_traffic_health_check" {
  security_group_id            = var.container_sg_id
  referenced_security_group_id = var.alb_sg_id
  description                  = "Allow HTTP traffic from ALB for health check"
  from_port                    = var.otel_gateway_health_port
  to_port                      = var.otel_gateway_health_port
  ip_protocol                  = "tcp"

  tags = merge(var.additional_tags, {
    Name = "hummingbird-container-allow-inbound-traffic-hc"
  })
}

resource "aws_vpc_security_group_egress_rule" "allow_container_outbound_traffic" {
  security_group_id = var.container_sg_id
  description       = "Allow all outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  tags = merge(var.additional_tags, {
    Name = "hummingbird-container-allow-outbound-traffic"
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
    resources = ["*"]
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "hummingbird-collector-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json

  tags = merge(var.additional_tags, {
    Name = "hummingbird-collector-ecs-task-execution-role"
  })
}

resource "aws_iam_role_policy" "ecs_role_policy" {
  name   = "hummingbird-collector-ecs-tasks-iam-role-policy"
  role   = aws_iam_role.ecs_task_execution_role.id
  policy = data.aws_iam_policy_document.ecs_iam_role_policy.json
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
        },
        {
          "name": "OTEL_GATEWAY_GRPC_PORT",
          "value": "${var.otel_gateway_grpc_port}"
        },
        {
          "name": "OTEL_GATEWAY_HTTP_PORT",
          "value": "${var.otel_gateway_http_port}"
        },
        {
          "name": "OTEL_GATEWAY_HEALTH_PORT",
          "value": "${var.otel_gateway_health_port}"
        },
        {
          "name": "APPLICATION_ENVIRONMENT",
          "value": "${var.application_environment}"
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
          "containerPort": ${var.otel_gateway_grpc_port},
          "hostPort": ${var.otel_gateway_grpc_port}
        },
        {
          "protocol": "tcp",
          "containerPort": ${var.otel_gateway_http_port},
          "hostPort": ${var.otel_gateway_http_port}
        },
        {
          "protocol": "tcp",
          "containerPort": ${var.otel_gateway_health_port},
          "hostPort": ${var.otel_gateway_health_port}
        }
      ],
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "curl -f http://localhost:${var.otel_gateway_health_port}/health || exit 1"
        ],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      },
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "${var.collector_log_group_name}",
          "awslogs-region": "${data.aws_region.current.name}",
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
  desired_count   = var.desired_task_count

  load_balancer {
    target_group_arn = aws_alb_target_group.alb_grpc_target_group.arn
    container_name   = "otel-gateway-collector"
    container_port   = var.otel_gateway_grpc_port
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.alb_http_target_group.arn
    container_name   = "otel-gateway-collector"
    container_port   = var.otel_gateway_http_port
  }

  network_configuration {
    assign_public_ip = false
    subnets          = var.private_subnet_ids
    security_groups  = [var.container_sg_id]
  }

  depends_on = [
    aws_ecs_cluster.ecs_cluster,
    aws_ecs_task_definition.ecs_task_definition,
    aws_alb_target_group.alb_grpc_target_group,
    aws_alb_target_group.alb_http_target_group
  ]

  tags = merge(var.additional_tags, {
    Name = "hummingbird-collector-ecs-service"
  })
}
