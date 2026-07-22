resource "aws_vpc" "openmetadata" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "openmetadata" {
  vpc_id = aws_vpc.openmetadata.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.openmetadata.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = local.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-${count.index + 1}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.openmetadata.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.openmetadata.id
  }

  tags = {
    Name = "${local.name_prefix}-public"
  }
}

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "alb" {
  name_prefix = "${local.name_prefix}-alb-"
  description = "Internet HTTP entry point restricted to operator CIDRs"
  vpc_id      = aws_vpc.openmetadata.id

  tags = {
    Name = "${local.name_prefix}-alb"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  for_each = toset(var.allowed_cidrs)

  security_group_id = aws_security_group.alb.id
  description       = "Short-lived HTTP access from ${each.value}"
  cidr_ipv4         = each.value
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_security_group" "instance" {
  name_prefix = "${local.name_prefix}-ec2-"
  description = "OpenMetadata host; no direct public ingress or SSH"
  vpc_id      = aws_vpc.openmetadata.id

  tags = {
    Name = "${local.name_prefix}-ec2"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "instance_from_alb" {
  security_group_id            = aws_security_group.instance.id
  description                  = "OpenMetadata UI and API from the ALB only"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 8585
  to_port                      = 8585
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_instance" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward requests and health checks to OpenMetadata"
  referenced_security_group_id = aws_security_group.instance.id
  from_port                    = 8585
  to_port                      = 8585
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "instance_ipv4" {
  security_group_id = aws_security_group.instance.id
  description       = "OS packages, container images, SSM, and AWS APIs"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

