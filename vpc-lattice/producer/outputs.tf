output "hosted_zone_id" {
  value       = aws_vpclattice_service_network_service_association.order.dns_entry[0].hosted_zone_id
  description = "ID de la zona hospedada para el servicio de VPC Lattice"
}

output "domain_name" {
  value       = aws_vpclattice_service_network_service_association.order.dns_entry[0].domain_name
  description = "Nombre DNS para el servicio de VPC Lattice"
}