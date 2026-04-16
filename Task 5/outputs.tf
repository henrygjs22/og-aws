output "network_vpc_id" {
  value = module.network_vpc.vpc_id
}

output "business_vpc_id" {
  value = module.business_vpc.vpc_id
}

output "business_nginx_private_ip" {
  value = aws_instance.business_nginx.private_ip
}

output "peering_id" {
  value = aws_vpc_peering_connection.network_to_business.id
}

output "client_vpn_endpoint_id" {
  value = local.vpn_enabled ? aws_ec2_client_vpn_endpoint.this[0].id : null
}