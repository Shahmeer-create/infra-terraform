# ---------------------------------------------------------------------------
# Bootstrap Variables
# ---------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "github_infra_repo" {
  description = "GitHub repo for infra (owner/repo)"
  type        = string
  # Example: "Shahmeer-create/infra-terraform"
}

variable "github_app_repo" {
  description = "GitHub repo for app code (owner/repo)"
  type        = string
  # Example: "Shahmeer-create/my-app"
}
