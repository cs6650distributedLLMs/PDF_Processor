output "ecr_repository_arn" {
  value = aws_ecr_repository.ecr_repository.arn
}

output "image_uri" {
  value = "${aws_ecr_repository.ecr_repository.repository_url}:${random_uuid.image_tag.result}"
}
