###############################################################################
# Module: vpc — Custom VPC with public + private subnets across 2 AZs
#
# Based on week8 (modules/vpc) with the following additions:
#   - Private route table (no NAT route — same approach as week5/7/8 labs;
#     private subnets are isolated, used only by RDS)
#   - Explicit name_prefix instead of project_name, for consistency with
#     the queue and db modules
#   - DB subnet group output, so the db module can place RDS in private subnets
###############################################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-igw"
  })
}

# --- Public subnets (one per AZ, auto-assign public IP) -----------------------

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-${count.index + 1}"
    Tier = "public"
  })
}

# --- Private subnets (no auto-IP, no NAT — host RDS only) ---------------------

resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-${count.index + 1}"
    Tier = "private"
  })
}

# --- Route tables -------------------------------------------------------------

# Public RT: default route to the Internet Gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private RT: NO default route. Private subnets are isolated by design.
# (Adding NAT here would cost ~$30/month and we don't need it: RDS does
# not initiate outbound traffic.)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-rt"
  })
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# --- DB subnet group (consumed by the db module) ------------------------------

resource "aws_db_subnet_group" "main" {
  name        = "${var.name_prefix}-db-subnet-group"
  description = "Private subnets for ${var.name_prefix} RDS instances"
  subnet_ids  = aws_subnet.private[*].id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db-subnet-group"
  })
}
