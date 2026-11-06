# Dev environment variables
# Usage: terraform apply -var-file=dev.tfvars

project_name             = "myapp"
environment              = "dev"
aws_region               = "us-east-1"

# Networking
enable_nat_ha            = false

# Database
db_instance_class        = "db.t3.micro"
db_multi_az              = false
enable_deletion_protection = false

# ECS
task_cpu                 = 256
task_memory              = 512
desired_count            = 1
enable_autoscaling       = false

# Logging
log_retention_days       = 7

# Monitoring
enable_alarms            = false

# HTTPS / WAF (disabled for dev)
enable_https             = false
enable_waf               = false
