# ---------------------------------------------------------------------------
# Security Groups
# Principle: least privilege — each SG only allows the minimum required traffic
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# ALB Security Group
# ---------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Allow inbound HTTP/HTTPS from the internet; egress only to VPC"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = var.enable_https ? [1] : []
    content {
      description = "HTTPS from internet"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    description = "Egress to VPC CIDR only"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name = "${local.name_prefix}-alb-sg"
  }
}

# ---------------------------------------------------------------------------
# ECS Security Group
# ---------------------------------------------------------------------------

resource "aws_security_group" "ecs" {
  name        = "${local.name_prefix}-ecs-sg"
  description = "Allow inbound from ALB on container port; full egress for ECR, SecretsManager, etc."
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Container port from ALB only"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All outbound (needed for ECR pull, Secrets Manager, S3 endpoint)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-ecs-sg"
  }
}

# ---------------------------------------------------------------------------
# RDS Security Group
# ---------------------------------------------------------------------------

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Allow MySQL from ECS tasks only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from ECS tasks"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  # No egress rule — RDS does not initiate outbound connections

  tags = {
    Name = "${local.name_prefix}-rds-sg"
  }
}

# ---------------------------------------------------------------------------
# Rotation Lambda Security Group
# ---------------------------------------------------------------------------

resource "aws_security_group" "rotation_lambda" {
  name        = "${local.name_prefix}-rotation-lambda-sg"
  description = "Allows the Secrets Manager rotation Lambda to reach RDS and Secrets Manager"
  vpc_id      = aws_vpc.main.id

  egress {
    description     = "MySQL to RDS"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.rds.id]
  }

  egress {
    description = "HTTPS to Secrets Manager"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-rotation-lambda-sg"
  }
}

# Allow RDS to receive connections from the rotation Lambda
resource "aws_security_group_rule" "rds_from_rotation" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.rotation_lambda.id
  description              = "MySQL from rotation Lambda"
}
