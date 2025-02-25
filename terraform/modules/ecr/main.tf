resource "aws_ecr_repository" "ecr_repository" {
  name = var.ecr_repository_name

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

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "ecr_repository_policy_document" {
  statement {
    sid    = "AllowECRRepositoryAccess"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }

    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeRepositories",
      "ecr:GetRepositoryPolicy",
      "ecr:ListImages",
      "ecr:DeleteRepository",
      "ecr:BatchDeleteImage",
      "ecr:SetRepositoryPolicy",
      "ecr:DeleteRepositoryPolicy",
    ]
  }
}

resource "aws_ecr_repository_policy" "ecr_repository_policy" {
  repository = aws_ecr_repository.ecr_repository.name
  policy     = data.aws_iam_policy_document.ecr_repository_policy_document.json
}

locals {
  files_to_hash = setsubtract(
    fileset(var.docker_build_context, "**/*"),
    fileset(var.docker_build_context, "node_modules/**/*")
  )
  file_hashes = {
    for file in local.files_to_hash :
    file => filesha256("${var.docker_build_context}/${file}")
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
    command     = "docker build --platform linux/amd64 --tag ${aws_ecr_repository.ecr_repository.repository_url}:${random_uuid.image_tag.result} ."
    working_dir = var.docker_build_context
  }

  triggers = {
    should_trigger_resource = local.source_directory_hash
  }

  depends_on = [aws_ecr_repository.ecr_repository]
}

resource "null_resource" "login_to_ecr" {
  provisioner "local-exec" {
    command = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.ecr_repository.repository_url}"
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

  depends_on = [
    aws_ecr_repository.ecr_repository,
    aws_ecr_repository_policy.ecr_repository_policy,
    null_resource.build_docker_image
  ]
}
