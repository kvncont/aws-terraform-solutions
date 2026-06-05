data "aws_availability_zones" "available" {
  state = "available"
}

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
    Name                                          = "subnet-${local.project_name}-${count.index + 1}"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
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

###########################
##### Security Groups
###########################

resource "aws_security_group" "eks_cluster_sg" {
  name        = local.sg_controlplane_name
  description = "Communication between the control plane and worker nodegroups"
  vpc_id      = local.network_vpc_id
  tags = {
    Name = local.sg_controlplane_name
  }
}

resource "aws_security_group" "shared_node_sg" {
  name        = local.sg_shared_node_name
  description = "Communication between all nodes in the cluster"
  vpc_id      = local.network_vpc_id
  tags = {
    Name = local.sg_shared_node_name
  }
}

###########################
##### Ingress / Egress
###########################

resource "aws_security_group_rule" "ingress_cluster_to_node" {
  description              = "Allow managed and unmanaged nodes to communicate with each other (all ports)"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.shared_node_sg.id
  source_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  to_port                  = var.ingress_sg_to_port
  type                     = "ingress"
}

resource "aws_security_group_rule" "egress_node" {
  type              = "egress"
  to_port           = 0
  protocol          = "-1"
  from_port         = 0
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.shared_node_sg.id
}

resource "aws_security_group_rule" "ingress_inter_node" {
  description              = "Allow managed and unmanaged nodes to communicate with each other (all ports)"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.shared_node_sg.id
  source_security_group_id = aws_security_group.shared_node_sg.id
  to_port                  = var.ingress_sg_to_port
  type                     = "ingress"
}

resource "aws_security_group_rule" "ingress_node_to_cluster" {
  description              = "Allow unmanaged nodes to communicate with control plane (all ports)"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  source_security_group_id = aws_security_group.shared_node_sg.id
  to_port                  = var.ingress_sg_to_port
  type                     = "ingress"
}

resource "aws_security_group_rule" "ingress_control_plane" {
  description       = "Allow inbound traffic to EKS API"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.admin_cidr
  security_group_id = aws_security_group.eks_cluster_sg.id
}

resource "aws_security_group_rule" "egress_control_plane" {
  type              = "egress"
  to_port           = 0
  protocol          = "-1"
  from_port         = 0
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_cluster_sg.id
}
