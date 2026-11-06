# ---------------------------------------------------------------------------
# RDS — MySQL 8.0, private subnets, Secrets Manager credentials
# ---------------------------------------------------------------------------

resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name        = "${local.name_prefix}-db-subnet-group"
  description = "Private subnets for RDS instance"
  subnet_ids  = aws_subnet.private[*].id

  tags = {
    Name = "${local.name_prefix}-db-subnet-group"
  }
}

# KMS key for RDS storage encryption
resource "aws_kms_key" "rds" {
  description             = "KMS key for ${local.name_prefix} RDS storage encryption"
  deletion_window_in_days = 14
  enable_key_rotation     = true

  tags = {
    Name = "${local.name_prefix}-rds-kms"
  }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${local.name_prefix}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# RDS MySQL Instance
resource "aws_db_instance" "main" {
  identifier = "${local.name_prefix}-mysql"

  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.db_instance_class

  db_name  = var.db_name
  username = "admin"
  password = random_password.db.result

  # Storage
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds.arn

  # Network
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = var.db_multi_az

  # Backup
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # Deletion protection
  deletion_protection = var.enable_deletion_protection
  skip_final_snapshot = var.environment != "prod"
  final_snapshot_identifier = var.environment == "prod" ? "${local.name_prefix}-final-snapshot" : null

  # Performance Insights (enabled for prod)
  performance_insights_enabled = var.environment == "prod"

  # Parameter group defaults (MySQL 8.0)
  parameter_group_name = "default.mysql8.0"

  # Option group defaults
  auto_minor_version_upgrade = true

  tags = {
    Name = "${local.name_prefix}-mysql"
  }
}
