# ---------------------------------------------------------------------------
# Bootstrap Outputs
# Use these values to configure infra-terraform and GitHub secrets
# ---------------------------------------------------------------------------

output "state_bucket_name" {
  description = "S3 bucket name for Terraform state — update backend.tf with this"
  value       = aws_s3_bucket.state.bucket
}

output "lock_table_name" {
  description = "DynamoDB table name for state locking — update backend.tf with this"
  value       = aws_dynamodb_table.locks.name
}

output "github_oidc_role_arn" {
  description = "Set this as AWS_OIDC_ROLE_ARN secret in infra-terraform repo"
  value       = aws_iam_role.github_oidc_infra.arn
}

output "github_oidc_app_role_arn" {
  description = "Set this as AWS_OIDC_ROLE_ARN secret in my-app repo"
  value       = aws_iam_role.github_oidc_app.arn
}

output "next_steps" {
  description = "What to do after bootstrap"
  value       = <<-EOT
    1. Update infra-terraform/backend.tf:
       bucket = "${aws_s3_bucket.state.bucket}"

    2. Set GitHub secret in infra-terraform repo:
       AWS_OIDC_ROLE_ARN = "${aws_iam_role.github_oidc_infra.arn}"
       GH_ACCESS_TOKEN   = your GitHub personal access token

    3. Set GitHub secret in my-app repo:
       AWS_OIDC_ROLE_ARN = "${aws_iam_role.github_oidc_app.arn}"

    4. Run infra-terraform:
       cd .. && tf apply

    5. Push to GitHub — pipelines take over!
  EOT
}
