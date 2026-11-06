# ---------------------------------------------------------------------------
# ECR — Container registry for the backend image
# ---------------------------------------------------------------------------

resource "aws_ecr_repository" "backend" {
  name                 = "${local.name_prefix}-backend"
  image_tag_mutability = "MUTABLE"
  force_delete         = !var.enable_deletion_protection

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${local.name_prefix}-backend"
  }
}

resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 3 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 3
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only the last 20 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "sha-", "latest"]
          countType     = "imageCountMoreThan"
          countNumber   = 20
        }
        action = { type = "expire" }
      },
    ]
  })
}
