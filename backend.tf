terraform {
  backend "s3" {
    bucket       = "infra-tf-state-516027198635"
    key          = "infra-terraform/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}