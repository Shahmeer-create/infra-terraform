# ---------------------------------------------------------------------------
# Outputs — consumed by CI/CD and referenced by other stacks
# ---------------------------------------------------------------------------

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "rds_endpoint" {
  description = "RDS instance endpoint (host:port)"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "ecr_repository_url" {
  description = "ECR repository URL for the backend image"
  value       = aws_ecr_repository.backend.repository_url
}

output "amplify_app_url" {
  description = "Default domain URL of the Amplify app"
  value       = "https://${var.github_branch}.${aws_amplify_app.frontend.default_domain}"
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "secrets_manager_secret_arn" {
  description = "ARN of the Secrets Manager secret holding RDS credentials"
  value       = aws_secretsmanager_secret.rds.arn
  sensitive   = true
}

output "github_oidc_role_arn" {
  description = "ARN of the OIDC role for infra repo — set as AWS_OIDC_ROLE_ARN in Shahmeer-create/infra-terraform"
  value       = aws_iam_role.github_oidc.arn
}

output "github_oidc_app_role_arn" {
  description = "ARN of the OIDC role for app repo — set as AWS_OIDC_ROLE_ARN in Shahmeer-create/my-app"
  value       = aws_iam_role.github_oidc_app.arn
}
