# ---------------------------------------------------------------------------
# Project-level variables
# ---------------------------------------------------------------------------

variable "project_name" {
  description = "Short name used as prefix for all resources"
  type        = string
  default     = "myapp"
}

variable "environment" {
  description = "Deployment environment: dev, staging, or prod"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_nat_ha" {
  description = "false = single NAT Gateway (dev); true = one NAT per AZ (prod)"
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# GitHub / OIDC
# ---------------------------------------------------------------------------

variable "github_repo" {
  description = "GitHub repo for the infra (owner/repo) used for OIDC trust"
  type        = string
  default     = "Shahmeer-create/infra-terraform"
}

variable "github_app_repo" {
  description = "GitHub repo for the application code (owner/repo)"
  type        = string
  default     = "Shahmeer-create/my-app"
}

variable "github_branch" {
  description = "Branch that is allowed to assume the GitHub OIDC role"
  type        = string
  default     = "main"
}

# ---------------------------------------------------------------------------
# Database
# ---------------------------------------------------------------------------

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_multi_az" {
  description = "Enable Multi-AZ for RDS (prod recommended)"
  type        = bool
  default     = false
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "myapp"
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection on RDS (set true for prod)"
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# ECS / Container
# ---------------------------------------------------------------------------

variable "container_port" {
  description = "Port the backend container listens on"
  type        = number
  default     = 3000
}

variable "task_cpu" {
  description = "Fargate task CPU units"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory (MiB)"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired number of running ECS tasks"
  type        = number
  default     = 2
}

variable "enable_autoscaling" {
  description = "Enable Application Auto Scaling for ECS tasks"
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# HTTPS / WAF
# ---------------------------------------------------------------------------

variable "enable_https" {
  description = "Enable HTTPS on the ALB (requires certificate_arn)"
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS (required when enable_https=true)"
  type        = string
  default     = ""
}

variable "enable_waf" {
  description = "Attach a WAF WebACL with managed rule sets to the ALB"
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Monitoring
# ---------------------------------------------------------------------------

variable "enable_alarms" {
  description = "Create CloudWatch alarms and dashboard"
  type        = bool
  default     = true
}

variable "alarm_email" {
  description = "Email address for CloudWatch alarm notifications (empty = no email subscription)"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "CloudWatch log group retention in days"
  type        = number
  default     = 30
}

variable "github_access_token" {
  description = "GitHub personal access token for Amplify"
  type        = string
  sensitive   = true
  default     = ""
}

# ---------------------------------------------------------------------------
# CodePipeline
# ---------------------------------------------------------------------------

variable "github_connection_arn" {
  description = "AWS CodeStar connection ARN for GitHub (create manually in console)"
  type        = string
  default     = ""
}
