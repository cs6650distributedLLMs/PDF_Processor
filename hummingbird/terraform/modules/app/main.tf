resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/24"

  tags = merge(var.additional_tags, {
    Name = "hummingbird-vpc"
  })
}

resource "aws_subnet" "public_subnet_one" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.0.0/26"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = merge(var.additional_tags, {
    Name = "hummingbird-public-subnet-one"
  })
}

resource "aws_subnet" "public_subnet_two" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.0.64/26"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = merge(var.additional_tags, {
    Name = "hummingbird-public-subnet-two"
  })
}

resource "aws_subnet" "private_subnet_one" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.0.128/26"
  availability_zone = "${var.aws_region}a"

  tags = merge(var.additional_tags, {
    Name = "hummingbird-private-subnet-one"
  })
}

resource "aws_subnet" "private_subnet_two" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.0.192/26"
  availability_zone = "${var.aws_region}b"

  tags = merge(var.additional_tags, {
    Name = "hummingbird-private-subnet-two"
  })
}

resource "aws_internet_gateway" "internet_gateway" {
  tags = merge(var.additional_tags, {
    Name = "hummingbird-internet-gateway"
  })
}

resource "aws_internet_gateway_attachment" "internet_gateway_attachment" {
  internet_gateway_id = aws_internet_gateway.internet_gateway.id
  vpc_id              = aws_vpc.vpc.id
}

resource "aws_route_table" "public_route_table" {
  vpc_id     = aws_vpc.vpc.id
  depends_on = [aws_vpc.vpc]

  tags = merge(var.additional_tags, {
    Name = "hummingbird-public-route-table"
  })
}

resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet_gateway.id
}

resource "aws_route_table_association" "public_subnet_one_association" {
  subnet_id      = aws_subnet.public_subnet_one.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_two_association" {
  subnet_id      = aws_subnet.public_subnet_two.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_eip" "nat_gateway_one_attachment" {
  domain = "vpc"

  tags = merge(var.additional_tags, {
    Name = "hummingbird-nat-gateway-one"
  })
}

resource "aws_eip" "nat_gateway_two_attachment" {
  domain = "vpc"

  tags = merge(var.additional_tags, {
    Name = "hummingbird-nat-gateway-two"
  })
}

resource "aws_nat_gateway" "nat_gateway_one" {
  allocation_id = aws_eip.nat_gateway_one_attachment.allocation_id
  subnet_id     = aws_subnet.public_subnet_one.id

  tags = merge(var.additional_tags, {
    Name = "hummingbird-nat-gateway-one"
  })
}

resource "aws_nat_gateway" "nat_gateway_two" {
  allocation_id = aws_eip.nat_gateway_two_attachment.allocation_id
  subnet_id     = aws_subnet.public_subnet_two.id

  tags = merge(var.additional_tags, {
    Name = "hummingbird-nat-gateway-two"
  })
}

resource "aws_route_table" "private_route_table_one" {
  vpc_id     = aws_vpc.vpc.id
  depends_on = [aws_vpc.vpc]

  tags = merge(var.additional_tags, {
    Name = "hummingbird-private-route-table-one"
  })
}

resource "aws_route" "private_route_one" {
  route_table_id         = aws_route_table.private_route_table_one.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway_one.id
  depends_on             = [aws_nat_gateway.nat_gateway_one]
}

resource "aws_route_table_association" "private_route_table_one_association" {
  route_table_id = aws_route_table.private_route_table_one.id
  subnet_id      = aws_subnet.private_subnet_one.id
  depends_on     = [aws_route.private_route_one]
}

resource "aws_route_table" "private_route_table_two" {
  vpc_id     = aws_vpc.vpc.id
  depends_on = [aws_vpc.vpc]

  tags = merge(var.additional_tags, {
    Name = "hummingbird-private-route-table-two"
  })
}

resource "aws_route" "private_route_two" {
  route_table_id         = aws_route_table.private_route_table_two.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway_two.id
  depends_on             = [aws_nat_gateway.nat_gateway_two]
}

resource "aws_route_table_association" "private_route_table_two_association" {
  route_table_id = aws_route_table.private_route_table_two.id
  subnet_id      = aws_subnet.private_subnet_two.id
  depends_on     = [aws_route.private_route_two]
}

resource "aws_vpc_endpoint" "dynamo_db_endpoint" {
  vpc_id       = aws_vpc.vpc.id
  service_name = "com.amazonaws.${var.aws_region}.dynamodb"
  route_table_ids = [
    aws_route_table.private_route_table_one.id,
    aws_route_table.private_route_table_two.id,
  ]

  tags = merge(var.additional_tags, {
    Name = "hummingbird-dynamodb-endpoint"
  })
}

data "aws_iam_policy_document" "dynamo_db_endpoint_policy" {
  statement {
    sid       = "DynamoDBEndpointPolicy"
    effect    = "Allow"
    actions   = ["dynamodb:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
  }
}

resource "aws_vpc_endpoint_policy" "dynamo_db_endpoint_policy" {
  vpc_endpoint_id = aws_vpc_endpoint.dynamo_db_endpoint.id
  policy          = data.aws_iam_policy_document.dynamo_db_endpoint_policy.json
}

resource "aws_security_group" "alb_security_group" {
  name        = "hummingbird-alb-security-group"
  description = "controls access to the ALB"
  vpc_id      = aws_vpc.vpc.id

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
  name = "hummingbird-alb"
  subnets = [
    aws_subnet.public_subnet_one.id,
    aws_subnet.public_subnet_two.id,
  ]
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
  vpc_id      = aws_vpc.vpc.id
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
  vpc_id      = aws_vpc.vpc.id

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
      "image": "${var.image_uri}",
      "essential": true,
      "environment": [
        {"name": "HUMMINGBIRD_DYNAMO_TABLE", "value": "${var.dynamodb_table_name}"},
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
      }
    }
  ]
  TASK_DEFINITION
  network_mode          = "awsvpc"
  memory                = "512"
  cpu                   = "256"

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
    subnets = [
      aws_subnet.private_subnet_one.id,
      aws_subnet.private_subnet_two.id,
    ]
    security_groups = [
      aws_security_group.container_security_group.id
    ]
  }

  depends_on = [
    aws_ecs_cluster.ecs_cluster,
    aws_ecs_task_definition.ecs_task_definition,
    aws_subnet.private_subnet_one,
    aws_subnet.private_subnet_two,
    aws_alb_target_group.alb_target_group
  ]

  tags = merge(var.additional_tags, {
    Name = "hummingbird-ecs-service"
  })
}
