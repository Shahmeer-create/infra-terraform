# Prod environment variables
# Usage: terraform apply -var-file=prod.tfvars

project_name             = "myapp"
environment              = "prod"
aws_region               = "us-east-1"

# Networking
enable_nat_ha            = true

# Database
db_instance_class        = "db.t3.small"
db_multi_az              = true
enable_deletion_protection = true

# ECS
task_cpu                 = 512
task_memory              = 1024
desired_count            = 2
enable_autoscaling       = true

# Logging
log_retention_days       = 90

# Monitoring
enable_alarms            = true
alarm_email              = ""

# HTTPS / WAF (enable when cert is ready)
enable_https             = false
enable_waf               = true
certificate_arn          = ""
