# ---------------------------------------------------------------------------
# IAM Roles and Policies
# Five roles: ECS Task Execution, ECS Task, GitHub OIDC (infra), GitHub OIDC (app), Amplify
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# ECS Task Execution Role
# Used by the ECS agent to pull images from ECR and write CloudWatch logs
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ecs_task_execution_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${local.name_prefix}-ecs-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume.json
}

# Attach the AWS managed ECS task execution policy
resource "aws_iam_role_policy_attachment" "ecs_task_execution_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Inline policy: Secrets Manager access (scoped to RDS secret only) + ECR + CloudWatch
data "aws_iam_policy_document" "ecs_task_execution_inline" {
  statement {
    sid    = "GetRDSSecret"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [aws_secretsmanager_secret.rds.arn]
  }

  statement {
    sid    = "ECRPull"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${local.name_prefix}-backend:*"]
  }
}

resource "aws_iam_role_policy" "ecs_task_execution_inline" {
  name   = "${local.name_prefix}-ecs-execution-inline"
  role   = aws_iam_role.ecs_task_execution.id
  policy = data.aws_iam_policy_document.ecs_task_execution_inline.json
}

# ---------------------------------------------------------------------------
# ECS Task Role
# Used by the running container (application code) — S3 access only
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task" {
  name               = "${local.name_prefix}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

# Scoped S3 policy — only the photos bucket, only the photos/* prefix
data "aws_iam_policy_document" "ecs_task_s3" {
  statement {
    sid    = "S3PhotosObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.photos.arn}/photos/*"]
  }

  statement {
    sid    = "S3PhotosBucketLevel"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:HeadBucket",
    ]
    resources = [aws_s3_bucket.photos.arn]
  }
}

resource "aws_iam_role_policy" "ecs_task_s3" {
  name   = "${local.name_prefix}-ecs-task-s3"
  role   = aws_iam_role.ecs_task.id
  policy = data.aws_iam_policy_document.ecs_task_s3.json
}

# ---------------------------------------------------------------------------
# GitHub OIDC Identity Provider
# One provider shared by both OIDC roles below
# ---------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

# ---------------------------------------------------------------------------
# GitHub OIDC Role — Infra Repo (Shahmeer-create/infra-terraform)
# Used by terraform.yml: plan on PR, apply on push to main
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "github_oidc_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Wildcard allows both pull_request (plan) and push (apply) events
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_oidc" {
  name               = "${local.name_prefix}-github-oidc-role"
  assume_role_policy = data.aws_iam_policy_document.github_oidc_assume.json
}

# Full Terraform permissions for the infra repo
data "aws_iam_policy_document" "github_oidc_permissions" {
  statement {
    sid       = "EC2VPC"
    effect    = "Allow"
    actions   = ["ec2:*", "elasticloadbalancing:*"]
    resources = ["*"]
  }

  statement {
    sid       = "ECS"
    effect    = "Allow"
    actions   = ["ecs:*"]
    resources = ["*"]
  }

  statement {
    sid       = "RDS"
    effect    = "Allow"
    actions   = ["rds:*"]
    resources = ["*"]
  }

  statement {
    sid       = "S3"
    effect    = "Allow"
    actions   = ["s3:*"]
    resources = ["*"]
  }

  statement {
    sid       = "ECR"
    effect    = "Allow"
    actions   = ["ecr:*"]
    resources = ["*"]
  }

  statement {
    sid       = "SecretsManager"
    effect    = "Allow"
    actions   = ["secretsmanager:*"]
    resources = ["*"]
  }

  statement {
    sid    = "IAM"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:PassRole",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListInstanceProfilesForRole",
      "iam:CreateOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "CloudWatch"
    effect    = "Allow"
    actions   = ["cloudwatch:*", "logs:*", "sns:*"]
    resources = ["*"]
  }

  statement {
    sid       = "AutoScaling"
    effect    = "Allow"
    actions   = ["application-autoscaling:*"]
    resources = ["*"]
  }

  # DynamoDB — Terraform state lock table only
  statement {
    sid    = "DynamoDB"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:DescribeTable",
    ]
    resources = ["arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/myapp-terraform-locks"]
  }

  statement {
    sid       = "WAF"
    effect    = "Allow"
    actions   = ["wafv2:*"]
    resources = ["*"]
  }

  statement {
    sid       = "Amplify"
    effect    = "Allow"
    actions   = ["amplify:*"]
    resources = ["*"]
  }

  statement {
    sid       = "KMS"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid       = "Lambda"
    effect    = "Allow"
    actions   = ["lambda:*"]
    resources = ["*"]
  }

  statement {
    sid       = "SAR"
    effect    = "Allow"
    actions   = ["serverlessrepo:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_oidc_permissions" {
  name   = "${local.name_prefix}-github-oidc-permissions"
  role   = aws_iam_role.github_oidc.id
  policy = data.aws_iam_policy_document.github_oidc_permissions.json
}

# ---------------------------------------------------------------------------
# GitHub OIDC Role — App Repo (Shahmeer-create/my-app)
# Used by deploy.yml: build Docker image, push to ECR, update ECS service
# Minimal permissions — only what the deploy workflow actually needs
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "github_oidc_app_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Allow any ref/event from the app repo
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_app_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_oidc_app" {
  name               = "${local.name_prefix}-github-oidc-app-role"
  assume_role_policy = data.aws_iam_policy_document.github_oidc_app_assume.json
}

data "aws_iam_policy_document" "github_oidc_app_permissions" {
  # ECR auth token (must be Resource: * — it's a global action)
  statement {
    sid       = "ECRAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # ECR push — scoped to the backend repo only
  statement {
    sid    = "ECRPush"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:BatchGetImage",
      "ecr:DescribeRepositories",
      "ecr:DescribeImages",
    ]
    resources = [aws_ecr_repository.backend.arn]
  }

  # ECS read — describe current task definition and service state
  statement {
    sid    = "ECSRead"
    effect = "Allow"
    actions = [
      "ecs:DescribeTaskDefinition",
      "ecs:DescribeServices",
      "ecs:DescribeClusters",
      "ecs:ListTaskDefinitions",
    ]
    resources = ["*"]
  }

  # ECS write — register new task def and trigger rolling deploy
  statement {
    sid    = "ECSWrite"
    effect = "Allow"
    actions = [
      "ecs:RegisterTaskDefinition",
      "ecs:UpdateService",
    ]
    resources = ["*"]
  }

  # PassRole — ECS needs this to attach execution + task roles to new task def
  statement {
    sid    = "PassRoleToECS"
    effect = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      aws_iam_role.ecs_task_execution.arn,
      aws_iam_role.ecs_task.arn,
    ]
  }
}

resource "aws_iam_role_policy" "github_oidc_app_permissions" {
  name   = "${local.name_prefix}-github-oidc-app-permissions"
  role   = aws_iam_role.github_oidc_app.id
  policy = data.aws_iam_policy_document.github_oidc_app_permissions.json
}

# ---------------------------------------------------------------------------
# Amplify Service Role
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "amplify_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["amplify.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "amplify" {
  name               = "${local.name_prefix}-amplify-role"
  assume_role_policy = data.aws_iam_policy_document.amplify_assume.json
}

resource "aws_iam_role_policy_attachment" "amplify_managed" {
  role       = aws_iam_role.amplify.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess-Amplify"
}
