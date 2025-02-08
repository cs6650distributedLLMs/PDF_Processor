data "aws_region" "current" {
  name = "ca-west-1"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_dynamodb_table" "media_dynamo_table" {
  name         = "hummingbird-media"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  tags = merge(var.additional_tags, {
    Name = "hummingbird-media-dynamo-table"
  })
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/24"

  tags = merge(var.additional_tags, {
    Name = "hummingbird-vpc"
  })
}

resource "aws_subnet" "public_subnet_one" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.0.0/26"
  availability_zone       = element(data.aws_availability_zones.available.names, 0)
  map_public_ip_on_launch = true

  tags = merge(var.additional_tags, {
    Name = "hummingbird-public-subnet-one"
  })
}

resource "aws_subnet" "public_subnet_two" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.0.64/26"
  availability_zone       = element(data.aws_availability_zones.available.names, 1)
  map_public_ip_on_launch = true

  tags = merge(var.additional_tags, {
    Name = "hummingbird-public-subnet-two"
  })
}

resource "aws_subnet" "private_subnet_one" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.0.128/26"
  availability_zone = element(data.aws_availability_zones.available.names, 0)

  tags = merge(var.additional_tags, {
    Name = "hummingbird-private-subnet-one"
  })
}

resource "aws_subnet" "private_subnet_two" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.0.192/26"
  availability_zone = element(data.aws_availability_zones.available.names, 1)

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
  service_name = "com.amazonaws.${data.aws_region.current.name}.dynamodb"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "*"
        Principal = "*"
        Resource  = "*"
      }
    ]
  })
  route_table_ids = [
    aws_route_table.private_route_table_one.id,
    aws_route_table.private_route_table_two.id,
  ]
}

resource "aws_cloudwatch_log_group" "cw_log_group" {
  name              = "/ecs/hummingbird"
  retention_in_days = 7

  tags = merge(var.additional_tags, {
    Name = "hummingbird-cloudwatch-log-group"
  })
}

resource "aws_cloudwatch_log_stream" "cw_log_stream" {
  name           = "hummingbird-log-stream"
  log_group_name = aws_cloudwatch_log_group.cw_log_group.name
}

resource "aws_security_group" "alb_security_group" {
  name        = "cb-load-balancer-security-group"
  description = "controls access to the ALB"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = var.app_port
    to_port     = var.app_port
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
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
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id
  target_type = "ip"

  tags = merge(var.additional_tags, {
    Name = "hummingbird-alb-target-group"
  })
}

resource "aws_alb_listener" "alb_listener" {
  load_balancer_arn = aws_alb.alb.id
  port              = var.app_port
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.alb_target_group.id
    type             = "forward"
  }

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

resource "aws_iam_role" "ecs_task_execution_role" {
  assume_role_policy = jsonencode({
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  path = "/"

  tags = merge(var.additional_tags, {
    Name = "hummingbird-ecs-task-execution-role"
  })
}

resource "aws_iam_role_policy" "ecs_role_policy" {
  name = "ecs-service"
  role = aws_iam_role.ecs_task_execution_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:AttachNetworkInterface",
          "ec2:CreateNetworkInterface",
          "ec2:CreateNetworkInterfacePermission",
          "ec2:DeleteNetworkInterface",
          "ec2:DeleteNetworkInterfacePermission",
          "ec2:Describe*",
          "ec2:DetachNetworkInterface",
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_execution_policy" {
  name = "ecs-task-execution-policy"
  role = aws_iam_role.ecs_task_execution_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "dynamodb_table_access" {
  name = "dynamodb-table-access"
  role = aws_iam_role.ecs_task_execution_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:BatchGet*",
          "dynamodb:DescribeStream",
          "dynamodb:DescribeTable",
          "dynamodb:Get*",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchWrite*",
          "dynamodb:CreateTable",
          "dynamodb:Delete*",
          "dynamodb:Update*",
          "dynamodb:PutItem"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_ecs_task_definition" "ecs_task_definition" {
  family                   = "hummingbird"
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn
  requires_compatibilities = ["FARGATE"]

  container_definitions = <<TASK_DEFINITION
  [
    {
      "name": "hummingbird",
      "image": "${var.image_uri}",
      "essential": true,
      "environment": [
        {"name": "HUMMINGBIRD_DYNAMO_TABLE", "value": "${aws_dynamodb_table.media_dynamo_table.name}"}
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
          "awslogs-region": "${data.aws_region.current.name}",
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

  tags = merge(var.additional_tags, {
    Name = "hummingbird-ecs-service"
  })
}

resource "aws_s3_bucket" "media_bucket" {
  bucket = var.media_s3_bucket

  tags = merge(var.additional_tags, {
    Name = "hummingbird-media-bucket"
  })
}

resource "aws_s3_bucket_ownership_controls" "media_bucket_ownership_controls" {
  bucket = aws_s3_bucket.media_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "media_bucket_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.media_bucket_ownership_controls]

  bucket = aws_s3_bucket.media_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "media_bucket_public_access_block" {
  bucket = aws_s3_bucket.media_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_policy" "media_s3_access_policy" {
  name = "media-s3-access-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Effect = "Allow",
        Resource = [
          aws_s3_bucket.media_bucket.arn,
          "${aws_s3_bucket.media_bucket.arn}/*",
        ],
      },
    ]
  })
}
