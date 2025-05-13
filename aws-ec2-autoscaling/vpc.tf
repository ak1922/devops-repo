# VPC for resources
resource "aws_vpc" "app_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge({ Name = "${local.project_tags.app}-vpc" }, local.project_tags)
}

#------------ VPC subnets ------------
# Private subnets
resource "aws_subnet" "app_vpc_private" {
  count = length(var.private_subnets)

  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = data.aws_availability_zones.azs.names[count.index]

  tags = merge({ Name = "${local.project_tags.app}-vpc-privatesubnet-${count.index}" }, local.project_tags)
}

# Public subnets
resource "aws_subnet" "app_vpc_public" {
  count = length(var.public_subnets)

  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = data.aws_availability_zones.azs.names[count.index]
  map_public_ip_on_launch = true

  tags = merge({ Name = "${local.project_tags.app}-vpc-publicsubnet-${count.index}" }, local.project_tags)
}

#------------ Gateways -------------
# Internet Gateway
resource "aws_internet_gateway" "app_vpc_igw" {
  vpc_id = aws_vpc.app_vpc.id
  tags   = merge({ Name = "${local.project_tags.app}-vpc-igw" }, local.project_tags)
}

# Elastic IP
resource "aws_eip" "app_vpc_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.app_vpc_igw]

  tags = merge({ Name = "${local.project_tags.app}-vpc-eip" }, local.project_tags)
}

# Nat Gateway
resource "aws_nat_gateway" "app_vpc_nat" {
  allocation_id = aws_eip.app_vpc_eip.id
  subnet_id     = aws_subnet.app_vpc_public.*.id[0]

  depends_on = [aws_internet_gateway.app_vpc_igw]
}

#--------- Route tables ----------
resource "aws_route_table" "private_table" {
  vpc_id = aws_vpc.app_vpc.id
  tags   = merge({ Name = "${local.project_tags.app}-vpc-pri-table" }, local.project_tags)
}

resource "aws_route_table" "public_table" {
  vpc_id = aws_vpc.app_vpc.id
  tags   = merge({ Name = "${local.project_tags.app}-vpc-pub-table" }, local.project_tags)
}

resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.app_vpc_nat.id
}

resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.app_vpc_igw.id
}

resource "aws_route_table_association" "private_assoc" {
  count = length(var.private_subnets)

  route_table_id = aws_route_table.private_table.id
  subnet_id      = aws_subnet.app_vpc_private.*.id[count.index]
}

resource "aws_route_table_association" "public_assoc" {
  count = length(var.public_subnets)

  subnet_id      = aws_subnet.app_vpc_public.*.id[count.index]
  route_table_id = aws_route_table.public_table.id
}

#----------- Security Groups -------------
# Load balancer security group
resource "aws_security_group" "lb_group" {
  name   = "${local.project_tags.app}-loadbalancer-sg"
  vpc_id = aws_vpc.app_vpc.id

  ingress {
    to_port     = 80
    from_port   = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    to_port     = 0
    from_port   = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Auto scaling security group
resource "aws_security_group" "asg_group" {
  name   = "${local.project_tags.app}-autoscaling-sg"
  vpc_id = aws_vpc.app_vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_group.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
