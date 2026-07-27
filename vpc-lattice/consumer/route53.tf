resource "aws_route53_zone_association" "consumer" {
  zone_id = data.terraform_remote_state.networking.outputs.private_hosted_zone_id
  vpc_id  = aws_vpc.consumer.id
}