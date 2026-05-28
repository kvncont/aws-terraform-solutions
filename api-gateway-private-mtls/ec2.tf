# =============================================================================
# EC2 para pruebas de mTLS
# - Sin IP pública (solo privada)
# - Acceso vía SSM Session Manager (no requiere SSH público)
# - user_data instala los certificados cliente y configura curl
# =============================================================================

# Obtener la AMI más reciente de Amazon Linux 2023
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ami_id = var.ec2_ami_id != "" ? var.ec2_ami_id : data.aws_ami.amazon_linux_2023.id
}

resource "aws_instance" "test_client" {
  ami                    = local.ami_id
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.ec2_test.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name

  # Sin IP pública — acceso solo vía SSM
  associate_public_ip_address = false

  key_name = var.ec2_key_pair_name != "" ? var.ec2_key_pair_name : null

  # Cifrado del volumen raíz
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_tokens                 = "required" # Requiere IMDSv2
    http_put_response_hop_limit = 1
    http_endpoint               = "enabled"
  }

  user_data_base64 = base64encode(templatefile("${path.module}/templates/ec2_userdata.sh.tpl", {
    custom_domain     = var.custom_domain
    aws_region        = var.aws_region
    project_name      = var.project_name
    truststore_bucket = aws_s3_bucket.truststore.bucket
  }))

  tags = {
    Name = "${var.project_name}-test-client"
    Role = "mTLS Test Client"
  }

  depends_on = [
    aws_vpc_endpoint.ssm,
    aws_vpc_endpoint.ssmmessages,
    aws_vpc_endpoint.ec2messages,
  ]

  lifecycle {
    ignore_changes = [ami]
  }
}
