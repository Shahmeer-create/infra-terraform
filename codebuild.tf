# ---------------------------------------------------------------------------
# CodeBuild — Builds Docker image, pushes to ECR, outputs imagedefinitions
# ---------------------------------------------------------------------------

resource "aws_codebuild_project" "app" {
  name          = "${local.name_prefix}-build"
  description   = "Build Docker image for ${local.name_prefix} backend"
  build_timeout = 20
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true # Required for Docker builds

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "ECR_REPO_URI"
      value = aws_ecr_repository.backend.repository_url
    }

    environment_variable {
      name  = "CONTAINER_NAME"
      value = "${local.name_prefix}-backend"
    }

    environment_variable {
      name  = "ECS_CLUSTER"
      value = aws_ecs_cluster.main.name
    }

    environment_variable {
      name  = "ECS_SERVICE"
      value = "${local.name_prefix}-backend"
    }

    environment_variable {
      name  = "TASK_DEFINITION_ARN"
      value = aws_ecs_task_definition.backend.arn
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/codebuild/${local.name_prefix}-build"
      stream_name = "build"
    }
  }

  tags = {
    Name = "${local.name_prefix}-build"
  }
}

# CloudWatch log group for CodeBuild logs
resource "aws_cloudwatch_log_group" "codebuild" {
  name              = "/codebuild/${local.name_prefix}-build"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "/codebuild/${local.name_prefix}-build"
  }
}

# ---------------------------------------------------------------------------
# CodeBuild — Scan project (ESLint syntax + security scan)
# Runs after Build stage, before Deploy
# ---------------------------------------------------------------------------

resource "aws_codebuild_project" "scan" {
  name          = "${local.name_prefix}-scan"
  description   = "Syntax and security scan for ${local.name_prefix} backend"
  build_timeout = 10
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = false
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec-scan.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/codebuild/${local.name_prefix}-scan"
      stream_name = "scan"
    }
  }

  tags = {
    Name = "${local.name_prefix}-scan"
  }
}

# CloudWatch log group for scan logs
resource "aws_cloudwatch_log_group" "codebuild_scan" {
  name              = "/codebuild/${local.name_prefix}-scan"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "/codebuild/${local.name_prefix}-scan"
  }
}
