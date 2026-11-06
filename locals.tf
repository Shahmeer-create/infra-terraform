# ---------------------------------------------------------------------------
# Local values — computed once, referenced everywhere
# ---------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Consistent name prefix for all resources
  name_prefix = "${var.project_name}-${var.environment}"

  # Common tags applied to every resource (supplementing provider default_tags)
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  # Availability zones — use the first 3
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  # Subnet CIDRs derived from vpc_cidr
  # Public subnets:  .0/24, .1/24, .2/24  (indices 0-2)
  # Private subnets: .3/24, .4/24, .5/24  (indices 3-5)
  public_subnet_cidrs = [
    cidrsubnet(var.vpc_cidr, 8, 1),
    cidrsubnet(var.vpc_cidr, 8, 2),
    cidrsubnet(var.vpc_cidr, 8, 3),
  ]

  private_subnet_cidrs = [
    cidrsubnet(var.vpc_cidr, 8, 4),
    cidrsubnet(var.vpc_cidr, 8, 5),
    cidrsubnet(var.vpc_cidr, 8, 6),
  ]

  # Number of NAT Gateways: 1 (dev) or 3 (prod HA)
  nat_gateway_count = var.enable_nat_ha ? 3 : 1
}
