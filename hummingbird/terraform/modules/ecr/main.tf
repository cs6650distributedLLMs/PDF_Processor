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
    "version": "2012-10-17",
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep only the last x images, expire all others",
            "selection": {
                "tagStatus": "any",
                "countType": "imageCountMoreThan",
                "countNumber": 10
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}

locals {
  build_path = "${path.module}/../../${var.docker_build_context}"
  files_to_hash = setsubtract(
    fileset(local.build_path, "**/*"),
    fileset(local.build_path, "node_modules/**/*")
  )
  file_hashes = {
    for file in local.files_to_hash :
    file => filesha256("${local.build_path}/${file}")
  }
  combined_hash_input   = join("", values(local.file_hashes))
  source_directory_hash = sha256(local.combined_hash_input)
}

resource "random_uuid" "image_tag" {
  keepers = {
    should_trigger_resource = local.source_directory_hash
  }
}

resource "null_resource" "build_docker_image" {
  provisioner "local-exec" {
    command     = "docker build -t ${aws_ecr_repository.ecr_repository.repository_url}:${random_uuid.image_tag.result} ."
    working_dir = var.docker_build_context
  }

  triggers = {
    should_trigger_resource = local.source_directory_hash
  }

  depends_on = [aws_ecr_repository.ecr_repository]
}

resource "null_resource" "push_docker_image" {
  provisioner "local-exec" {
    command = "docker push ${aws_ecr_repository.ecr_repository.repository_url}:${random_uuid.image_tag.result}"
  }

  triggers = {
    should_trigger_resource = local.source_directory_hash
  }

  depends_on = [null_resource.build_docker_image]
}
