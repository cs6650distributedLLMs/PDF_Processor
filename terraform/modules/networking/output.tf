output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "public_subnet_ids" {
  value = [
    aws_subnet.public_subnet_one.id,
    aws_subnet.public_subnet_two.id,
  ]
}

output "private_subnet_ids" {
  value = [
    aws_subnet.private_subnet_one.id,
    aws_subnet.private_subnet_two.id,
  ]
}

output "private_route_table_ids" {
  value = [
    aws_route_table.private_route_table_one.id,
    aws_route_table.private_route_table_two.id,
  ]
}
