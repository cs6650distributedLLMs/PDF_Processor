resource "aws_ecr_repository" "ecr_repository" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "IMMUTABLE"

  tags = merge(var.additional_tags, {
    Name = var.ecr_repository_name
  })
}

resource "aws_ecr_lifecycle_policy" "ecr_repository_lifecycle_policy" {
  repository = aws_ecr_repository.ecr_repository.name
  policy     = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep only the last two images, expire all others",
            "selection": {
                "tagStatus": "any",
                "countType": "imageCountMoreThan",
                "countNumber": 2
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}

resource "random_uuid" "image_tag" {}

resource "null_resource" "build_docker_image" {
  provisioner "local-exec" {
    command     = "docker build -t ${aws_ecr_repository.ecr_repository.repository_url}:${random_uuid.image_tag.result} ."
    working_dir = var.docker_build_context
  }

  depends_on = [aws_ecr_repository.ecr_repository]
}

resource "null_resource" "push_docker_image" {
  provisioner "local-exec" {
    command = "docker push ${aws_ecr_repository.ecr_repository.repository_url}:${random_uuid.image_tag.result}"
  }

  depends_on = [null_resource.build_docker_image]
}
