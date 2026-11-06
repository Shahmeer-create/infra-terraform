# ---------------------------------------------------------------------------
# AWS Amplify — Frontend (React/Vite from Shahmeer-create/my-app)
# ---------------------------------------------------------------------------

resource "aws_amplify_app" "frontend" {
  name         = "${local.name_prefix}-frontend"
  repository   = "https://github.com/${var.github_app_repo}"
  platform     = "WEB_COMPUTE"
  iam_service_role_arn = aws_iam_role.amplify.arn

  # OAuth token must be provided via environment variable AMPLIFY_ACCESS_TOKEN
  # or configured outside Terraform (GitHub App connection)
  # access_token = var.github_access_token

  # Build spec inline — matches the amplify.yml in your my-app repo
  build_spec = <<-EOT
    version: 1
    applications:
      - appRoot: frontend
        frontend:
          phases:
            preBuild:
              commands:
                - npm ci
            build:
              commands:
                - npm run build
          artifacts:
            baseDirectory: dist
            files:
              - "**/*"
          cache:
            paths:
              - node_modules/**/*
  EOT

  environment_variables = {
    VITE_API_URL = var.enable_https ? "https://${aws_lb.main.dns_name}" : "http://${aws_lb.main.dns_name}"
  }

  # Auto-detect framework
  enable_auto_branch_creation = false
  enable_branch_auto_deletion = true

  custom_rule {
    source = "/api/<*>"
    target = "${var.enable_https ? "https" : "http"}://${aws_lb.main.dns_name}/api/<*>"
    status = "200"
  }

  custom_rule {
    source = "</^[^.]+$|\.(?!(css|gif|ico|jpg|js|png|txt|svg|woff|woff2|ttf|map|json)$)([^.]+$)/>"
    target = "/index.html"
    status = "200"
  }

  tags = {
    Name = "${local.name_prefix}-frontend"
  }
}

resource "aws_amplify_branch" "main" {
  app_id      = aws_amplify_app.frontend.id
  branch_name = var.github_branch
  stage       = var.environment == "prod" ? "PRODUCTION" : "DEVELOPMENT"

  enable_auto_build = true
  enable_pull_request_preview = var.environment != "prod"

  environment_variables = {
    VITE_API_URL = var.enable_https ? "https://${aws_lb.main.dns_name}" : "http://${aws_lb.main.dns_name}"
  }

  tags = {
    Name = "${local.name_prefix}-frontend-${var.github_branch}"
  }
}
