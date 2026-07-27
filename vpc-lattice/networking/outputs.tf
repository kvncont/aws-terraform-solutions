output "vpc_lattice_service_network_id" {
  value       = aws_vpclattice_service_network.hub.id
  description = "ID del Service Network de VPC Lattice"
}

output "private_hosted_zone_id" {
  value       = aws_route53_zone.private.zone_id
  description = "ID de la zona hospedada privada de Route 53"
}