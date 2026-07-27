resource "aws_route53_zone_association" "producer" {
  zone_id = data.terraform_remote_state.networking.outputs.private_hosted_zone_id
  vpc_id  = aws_vpc.producer.id
}

resource "aws_route53_record" "order" {
  zone_id = data.terraform_remote_state.networking.outputs.private_hosted_zone_id
  name    = "order.example.com"
  type    = "A"

  alias {
    name                   = aws_vpclattice_service_network_service_association.order.dns_entry[0].domain_name
    zone_id                = aws_vpclattice_service_network_service_association.order.dns_entry[0].hosted_zone_id
    evaluate_target_health = true
  }
}