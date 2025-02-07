data "aws_region" "current" {
  name = "ca-west-1"
}

resource "aws_dynamodb_table" "media-dynamo-table" {
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

data "aws_availability_zones" "available" {
  state = "available"
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

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "hummingbird-ecs-cluster"

  tags = merge(var.additional_tags, {
    Name = "hummingbird-ecs-cluster"
  })
}

resource "aws_security_group" "container_security_group" {
  description = "Access to the Fargate containers"
  vpc_id      = aws_vpc.vpc.id

  tags = merge(var.additional_tags, {
    Name = "hummingbird-container-security-group"
  })
}
