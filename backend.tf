# Terraform S3 backend configuration
# State bucket and DynamoDB lock table must be created manually before running terraform init
terraform {
  backend "s3" {
    # REPLACE_ACCOUNT_ID with your 12-digit AWS account ID before running terraform init
    bucket         = "infra-tf-state-516027198635"
    key            = "infra-terraform/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "tf-state-lock"
  }
}
