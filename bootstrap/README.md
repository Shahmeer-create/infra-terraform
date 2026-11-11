# Bootstrap

Run this ONCE before deploying `infra-terraform`. It creates the foundational
resources that everything else depends on.

## What it creates

| Resource | Purpose |
|---|---|
| S3 bucket `infra-tf-state-{account_id}` | Stores Terraform remote state |
| DynamoDB table `myapp-terraform-locks` | Prevents concurrent Terraform runs |
| GitHub OIDC Identity Provider | Allows GitHub Actions to authenticate with AWS |
| IAM Role `myapp-dev-github-oidc-role` | Used by infra-terraform pipeline |
| IAM Role `myapp-dev-github-oidc-app-role` | Used by my-app pipeline |

## Why separate from infra-terraform?

Bootstrap uses **local state** (no S3 backend). This is intentional because:
- It creates the S3 bucket that infra-terraform uses as its backend
- You can't use S3 as a backend before the bucket exists
- Bootstrap runs once and rarely changes

## How to run

```cmd
cd bootstrap
terraform init
terraform apply
```

Type `yes` when prompted. Takes about 1 minute.

## After running

The output will show you exactly what to do next — set GitHub secrets and run infra-terraform.

## Destroying

If you destroy everything and want to start fresh:
1. Run `tf destroy` in infra-terraform first
2. Run `terraform destroy` in bootstrap
3. Empty the S3 state bucket manually (AWS Console) before destroying bootstrap
