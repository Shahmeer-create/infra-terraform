# ---------------------------------------------------------------------------
# VPC Endpoints
# S3 Gateway endpoint lets ECS tasks reach S3 without going through NAT,
# reducing cost and keeping traffic inside the AWS network.
# ---------------------------------------------------------------------------

data "aws_region" "current" {}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  # Associate with ALL private route tables so every private subnet
  # routes S3 traffic through the endpoint, not through NAT.
  route_table_ids = aws_route_table.private[*].id

  tags = {
    Name = "${local.name_prefix}-s3-endpoint"
  }
}
