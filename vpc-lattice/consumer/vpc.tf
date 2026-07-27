data "terraform_remote_state" "networking" {
  backend = "local"
  config = {
    path = "${path.module}/../networking/terraform.tfstate"
  }
}

resource "aws_vpc" "consumer" {
  cidr_block           = "10.2.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "vpc-consumer" }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.consumer.id
  cidr_block        = "10.2.11.0/24"
  availability_zone = "us-east-1a"
  tags              = { Name = "subnet-consumer-private-a" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.consumer.id
  cidr_block        = "10.2.12.0/24"
  availability_zone = "us-east-1b"
  tags              = { Name = "subnet-consumer-private-b" }
}
