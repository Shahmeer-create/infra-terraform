# ---------------------------------------------------------------------------
# Bootstrap — Run this ONCE before infra-terraform
# Creates: S3 state bucket, DynamoDB lock table, OIDC provider, IAM roles
# Uses LOCAL state (no backend needed — this IS the backend creator)
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # NO backend block — state stays local in bootstrap/terraform.tfstate
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# S3 Bucket — stores terraform.tfstate for infra-terraform
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "state" {
  bucket        = "infra-tf-state-${data.aws_caller_identity.current.account_id}"
  force_destroy = false

  tags = {
    Name      = "terraform-state"
    ManagedBy = "bootstrap"
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# DynamoDB Table — state locking (prevents concurrent applies)
# ---------------------------------------------------------------------------

resource "aws_dynamodb_table" "locks" {
  name         = "myapp-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name      = "terraform-locks"
    ManagedBy = "bootstrap"
  }
}

# ---------------------------------------------------------------------------
# GitHub OIDC Identity Provider
# Allows GitHub Actions to authenticate with AWS without storing keys
# ---------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]

  tags = {
    Name      = "github-oidc-provider"
    ManagedBy = "bootstrap"
  }
}

# ---------------------------------------------------------------------------
# GitHub OIDC Role — Infra Repo
# Used by infra-terraform pipeline to run terraform plan/apply
# Has full Terraform permissions
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "github_oidc_infra_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity", "sts:TagSession"]

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
      values   = [
        "repo:${var.github_infra_repo}:*",
        "repo:${split("/", var.github_infra_repo)[0]}@*${split("/", var.github_infra_repo)[1]}@*:*",
      ]
    }
  }
}

resource "aws_iam_role" "github_oidc_infra" {
  name               = "myapp-dev-github-oidc-role"
  assume_role_policy = data.aws_iam_policy_document.github_oidc_infra_assume.json

  tags = {
    ManagedBy = "bootstrap"
  }
}

resource "aws_iam_role_policy" "github_oidc_infra_permissions" {
  name   = "myapp-dev-github-oidc-permissions"
  role   = aws_iam_role.github_oidc_infra.id
  policy = data.aws_iam_policy_document.github_oidc_infra_permissions.json
}

data "aws_iam_policy_document" "github_oidc_infra_permissions" {
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
    sid     = "IAM"
    effect  = "Allow"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:PassRole",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:PutRolePolicy",
      "iam:DeleteRolePolicy", "iam:GetRolePolicy", "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies", "iam:TagRole", "iam:UntagRole",
      "iam:ListInstanceProfilesForRole", "iam:CreateOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider",
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
  statement {
    sid     = "DynamoDB"
    effect  = "Allow"
    actions = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem", "dynamodb:DescribeTable"]
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
  statement {
    sid       = "CloudFormation"
    effect    = "Allow"
    actions   = ["cloudformation:*"]
    resources = ["*"]
  }
}

# ---------------------------------------------------------------------------
# GitHub OIDC Role — App Repo
# Used by my-app pipeline to push Docker images and deploy to ECS
# Minimal permissions — only ECR + ECS
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "github_oidc_app_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity", "sts:TagSession"]

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
      values   = [
        "repo:${var.github_app_repo}:*",
        "repo:${split("/", var.github_app_repo)[0]}@*${split("/", var.github_app_repo)[1]}@*:*",
      ]
    }
  }
}

resource "aws_iam_role" "github_oidc_app" {
  name               = "myapp-dev-github-oidc-app-role"
  assume_role_policy = data.aws_iam_policy_document.github_oidc_app_assume.json

  tags = {
    ManagedBy = "bootstrap"
  }
}

resource "aws_iam_role_policy" "github_oidc_app_permissions" {
  name   = "myapp-dev-github-oidc-app-permissions"
  role   = aws_iam_role.github_oidc_app.id
  policy = data.aws_iam_policy_document.github_oidc_app_permissions.json
}

data "aws_iam_policy_document" "github_oidc_app_permissions" {
  statement {
    sid       = "ECRAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid     = "ECRPush"
    effect  = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability", "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer", "ecr:InitiateLayerUpload",
      "ecr:PutImage", "ecr:UploadLayerPart", "ecr:BatchGetImage",
      "ecr:DescribeRepositories", "ecr:DescribeImages",
    ]
    resources = ["arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/myapp-dev-backend"]
  }
  statement {
    sid     = "ECSRead"
    effect  = "Allow"
    actions = [
      "ecs:DescribeTaskDefinition", "ecs:DescribeServices",
      "ecs:DescribeClusters", "ecs:ListTaskDefinitions",
    ]
    resources = ["*"]
  }
  statement {
    sid     = "ECSWrite"
    effect  = "Allow"
    actions = ["ecs:RegisterTaskDefinition", "ecs:UpdateService", "ecs:RunTask"]
    resources = ["*"]
  }
  statement {
    sid       = "PassRole"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/myapp-dev-ecs-execution-role",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/myapp-dev-ecs-task-role",
    ]
  }
}
