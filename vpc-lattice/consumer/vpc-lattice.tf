resource "aws_vpclattice_service_network_vpc_association" "consumer" {
  service_network_identifier = data.terraform_remote_state.networking.outputs.vpc_lattice_service_network_id
  vpc_identifier             = aws_vpc.consumer.id
  # subnet_ids                = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}