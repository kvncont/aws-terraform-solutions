###########################
##### SG for Control Plane
###########################

resource "aws_security_group" "eks_cluster_sg" {
  name        = local.sg_controlplane_name
  description = "Communication between the control plane and worker nodegroups"
  vpc_id      = local.network_vpc_id
  tags = {
    Name = local.sg_controlplane_name
  }
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

###########################
##### SG for Nodes
###########################

resource "aws_security_group" "shared_node_sg" {
  name        = local.sg_shared_node_name
  description = "Communication between all nodes in the cluster"
  vpc_id      = local.network_vpc_id
  tags = {
    Name = local.sg_shared_node_name
  }
}

resource "aws_security_group_rule" "ingress_cluster_to_node" {
  description              = "Allow managed and unmanaged nodes to communicate with each other (all ports)"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.shared_node_sg.id
  source_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  to_port                  = var.ingress_sg_to_port
  type                     = "ingress"
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

resource "aws_security_group_rule" "egress_node" {
  type              = "egress"
  to_port           = 0
  protocol          = "-1"
  from_port         = 0
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.shared_node_sg.id
}

###########################
##### SG for EFS
###########################

resource "aws_security_group" "efs" {
  name        = local.sg_efs_name
  description = "Security group for EFS mount targets"
  vpc_id      = local.network_vpc_id

  tags = {
    Name = local.sg_efs_name
  }
}

resource "aws_security_group_rule" "efs_ingress_nfs_from_nodes" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.efs.id
  source_security_group_id = aws_security_group.shared_node_sg.id
  description              = "Allow NFS from EKS nodes"
}

resource "aws_security_group_rule" "efs_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.efs.id
  description       = "Allow all outbound traffic"
}
