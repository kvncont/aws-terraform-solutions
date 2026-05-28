# =============================================================================
# VPC principal
# =============================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true # Necesario para VPC Endpoint / Private Hosted Zone
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# =============================================================================
# Subnets privadas (sin ruta a Internet)
# =============================================================================

resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-private-${count.index + 1}"
    Tier = "private"
  }
}

# =============================================================================
# Tabla de rutas privada (sin ruta a Internet Gateway)
# =============================================================================

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-rt-private"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# =============================================================================
# Security Group: VPC Endpoint de API Gateway
# =============================================================================

resource "aws_security_group" "vpce_apigw" {
  name        = "${var.project_name}-sg-vpce-apigw"
  description = "Permite trafico HTTPS hacia el VPC Endpoint de API Gateway"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS desde la VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Todo trafico saliente"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg-vpce-apigw"
  }
}

# Security Group: VPC Endpoint execute-api — solo permite tráfico desde el ALB
# Esto evita que alguien pueda saltarse la verificación mTLS del ALB
# invocando el VPC Endpoint directamente.
resource "aws_security_group" "vpce_execute_api" {
  name        = "${var.project_name}-sg-vpce-execute-api"
  description = "Permite HTTPS al VPC Endpoint de execute-api solo desde el ALB interno"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTPS solo desde el ALB interno (previene bypass de mTLS)"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_internal.id]
  }

  # TEMPORAL: permite acceso directo desde la EC2 de pruebas (sin pasar por el ALB/mTLS)
  # Eliminar esta regla cuando terminen las pruebas
  ingress {
    description     = "TEMPORAL - HTTPS directo desde EC2 de pruebas"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_test.id]
  }

  egress {
    description = "Todo trafico saliente"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg-vpce-execute-api"
  }
}

# Security Group: ALB interno (mTLS)
resource "aws_security_group" "alb_internal" {
  name        = "${var.project_name}-sg-alb-internal"
  description = "Security Group para el ALB interno que verifica mTLS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS mTLS desde la VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "HTTPS hacia el VPC Endpoint de execute-api"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name = "${var.project_name}-sg-alb-internal"
  }
}

# =============================================================================
# Security Group: Lambda
# =============================================================================

resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-sg-lambda"
  description = "Security Group para Lambda dentro de la VPC"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Todo trafico saliente (servicios AWS via endpoints)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg-lambda"
  }
}

# =============================================================================
# Security Group: EC2 de pruebas
# =============================================================================

resource "aws_security_group" "ec2_test" {
  name        = "${var.project_name}-sg-ec2-test"
  description = "Security Group para la EC2 de pruebas"
  vpc_id      = aws_vpc.main.id

  # Solo tráfico SSH desde dentro de la VPC (sin acceso público)
  ingress {
    description = "SSH interno"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Todo trafico saliente"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg-ec2-test"
  }
}

# =============================================================================
# VPC Endpoint para SSM (permite acceso a la EC2 sin SSH publico via Session Manager)
# =============================================================================

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpce_apigw.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-vpce-ssm"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpce_apigw.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-vpce-ssmmessages"
  }
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpce_apigw.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-vpce-ec2messages"
  }
}

# =============================================================================
# VPC Endpoint para S3 (Gateway — necesario para que Lambda descargue capas)
# =============================================================================

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name = "${var.project_name}-vpce-s3"
  }
}
