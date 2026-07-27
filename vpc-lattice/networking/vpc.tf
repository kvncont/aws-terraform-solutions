resource "aws_vpc" "networking" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "vpc-networking" }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.networking.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags              = { Name = "subnet-private-a" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.networking.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  tags              = { Name = "subnet-private-b" }
}
