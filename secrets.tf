# ---------------------------------------------------------------------------
# Secrets Manager — RDS credentials with 30-day automatic rotation
# ---------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "rds" {
  name                    = "${local.name_prefix}/rds/credentials"
  description             = "RDS MySQL credentials for ${local.name_prefix}"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0

  tags = {
    Name = "${local.name_prefix}-rds-secret"
  }
}

resource "aws_secretsmanager_secret_version" "rds" {
  secret_id = aws_secretsmanager_secret.rds.id

  secret_string = jsonencode({
    username = "admin"
    password = random_password.db.result
    host     = aws_db_instance.main.address
    port     = "3306"
    dbname   = var.db_name
  })
}

# ---------------------------------------------------------------------------
# Secrets Manager Rotation
# Use the AWS-managed Serverless Application Repository rotation function
# for MySQL single-user rotation.
# ---------------------------------------------------------------------------

data "aws_partition" "current" {}

# Deploy the MySQL rotation Lambda from the Serverless Application Repository
resource "aws_serverlessapplicationrepository_cloudformation_stack" "rotation_lambda" {
  name             = "${local.name_prefix}-mysql-rotation"
  application_id   = "arn:${data.aws_partition.current.partition}:serverlessrepo:us-east-1:297356227824:applications/SecretsManagerRDSMySQLRotationSingleUser"
  semantic_version = "1.1.367"
  capabilities     = ["CAPABILITY_IAM", "CAPABILITY_RESOURCE_POLICY"]

  parameters = {
    functionName = "${local.name_prefix}-mysql-rotation"
    endpoint     = "https://secretsmanager.${var.aws_region}.amazonaws.com"
    vpcSecurityGroupIds = aws_security_group.rotation_lambda.id
    vpcSubnetIds        = join(",", aws_subnet.private[*].id)
  }
}

# Configure rotation on the secret
resource "aws_secretsmanager_secret_rotation" "rds" {
  secret_id           = aws_secretsmanager_secret.rds.id
  rotation_lambda_arn = aws_serverlessapplicationrepository_cloudformation_stack.rotation_lambda.outputs["RotationLambdaARN"]

  rotation_rules {
    automatically_after_days = 30
  }

  depends_on = [aws_secretsmanager_secret_version.rds]
}
