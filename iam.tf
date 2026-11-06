# ---------------------------------------------------------------------------
# IAM Roles and Policies
# Four roles: ECS Task Execution, ECS Task, GitHub OIDC, Amplify Service
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# ECS Task Execution Role
# Used by the ECS agent to pull images and write logs
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

resource "aws_iam_role_policy_attachment" "ecs_task_execution_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

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
# Used by the application code itself (S3 access)
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

data "aws_iam_policy_document" "ecs_task_s3" {
  statement {
    sid    = "S3PhotosBucket"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [
      "${aws_s3_bucket.photos.arn}/photos/*",
    ]
  }

  statement {
    sid    = "S3PhotosBucketList"
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
# GitHub OIDC Role
# Allows GitHub Actions to authenticate without stored AWS credentials
# ---------------------------------------------------------------------------

# Create the OIDC provider (Terraform creates this, no manual step needed)
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

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

data "aws_iam_policy_document" "github_oidc_permissions" {
  # EC2 / VPC / ELB
  statement {
    sid    = "EC2VPC"
    effect = "Allow"
    actions = [
      "ec2:*",
      "elasticloadbalancing:*",
    ]
    resources = ["*"]
  }

  # ECS
  statement {
    sid     = "ECS"
    effect  = "Allow"
    actions = ["ecs:*"]
    resources = ["*"]
  }

  # RDS
  statement {
    sid     = "RDS"
    effect  = "Allow"
    actions = ["rds:*"]
    resources = ["*"]
  }

  # S3 — Terraform state bucket + photos bucket
  statement {
    sid     = "S3"
    effect  = "Allow"
    actions = ["s3:*"]
    resources = ["*"]
  }

  # ECR
  statement {
    sid     = "ECR"
    effect  = "Allow"
    actions = ["ecr:*"]
    resources = ["*"]
  }

  # Secrets Manager
  statement {
    sid     = "SecretsManager"
    effect  = "Allow"
    actions = ["secretsmanager:*"]
    resources = ["*"]
  }

  # IAM — scoped to roles managed by this Terraform stack
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

  # CloudWatch
  statement {
    sid     = "CloudWatch"
    effect  = "Allow"
    actions = ["cloudwatch:*", "logs:*", "sns:*"]
    resources = ["*"]
  }

  # Application Auto Scaling
  statement {
    sid     = "AutoScaling"
    effect  = "Allow"
    actions = ["application-autoscaling:*"]
    resources = ["*"]
  }

  # DynamoDB — Terraform state lock table
  statement {
    sid     = "DynamoDB"
    effect  = "Allow"
    actions = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem", "dynamodb:DescribeTable"]
    resources = ["arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/tf-state-lock"]
  }

  # WAFv2
  statement {
    sid     = "WAF"
    effect  = "Allow"
    actions = ["wafv2:*"]
    resources = ["*"]
  }

  # Amplify
  statement {
    sid     = "Amplify"
    effect  = "Allow"
    actions = ["amplify:*"]
    resources = ["*"]
  }

  # KMS — for RDS encryption
  statement {
    sid     = "KMS"
    effect  = "Allow"
    actions = ["kms:*"]
    resources = ["*"]
  }

  # Lambda — for Secrets Manager rotation
  statement {
    sid     = "Lambda"
    effect  = "Allow"
    actions = ["lambda:*"]
    resources = ["*"]
  }

  # Serverless Application Repository — for rotation Lambda deployment
  statement {
    sid     = "SAR"
    effect  = "Allow"
    actions = ["serverlessrepo:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_oidc_permissions" {
  name   = "${local.name_prefix}-github-oidc-permissions"
  role   = aws_iam_role.github_oidc.id
  policy = data.aws_iam_policy_document.github_oidc_permissions.json
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
