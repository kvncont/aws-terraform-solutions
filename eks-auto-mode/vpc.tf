###########################
##### Network (VPC/Subnets)
###########################

resource "aws_vpc" "eks" {
  count = local.create_vpc ? 1 : 0

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "vpc-${local.project_name}"
  }
}

resource "aws_internet_gateway" "eks" {
  count = local.create_vpc ? 1 : 0

  vpc_id = aws_vpc.eks[0].id

  tags = {
    Name = "igw-${local.project_name}"
  }
}

resource "aws_subnet" "eks" {
  count = local.create_subnets ? local.network_subnet_count : 0

  vpc_id                  = local.network_vpc_id
  cidr_block              = var.cluster_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                              = "subnet-${local.project_name}-${count.index + 1}"
    "kubernetes.io/cluster/${local.eks_cluster_name}" = "shared"
    "kubernetes.io/role/elb"                          = "1"
    "kubernetes.io/subnet"                            = "public"
  }
}

resource "aws_route_table" "eks_public" {
  count = local.create_vpc ? 1 : 0

  vpc_id = aws_vpc.eks[0].id

  tags = {
    Name = "rtb-${local.project_name}-public"
  }
}

resource "aws_route" "eks_public_internet" {
  count = local.create_vpc ? 1 : 0

  route_table_id         = aws_route_table.eks_public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.eks[0].id
}

resource "aws_route_table_association" "eks_public" {
  count = local.create_vpc && local.create_subnets ? local.network_subnet_count : 0

  subnet_id      = aws_subnet.eks[count.index].id
  route_table_id = aws_route_table.eks_public[0].id
}
