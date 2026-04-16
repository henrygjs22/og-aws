provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  common_tags = {
    Project = var.project_name
    Managed = "terraform"
  }

  vpn_enabled = var.enable_vpn && var.server_certificate_arn != null && var.root_certificate_chain_arn != null

  network_private_route_tables = {
    for idx, rt_id in module.network_vpc.private_route_table_ids : tostring(idx) => rt_id
  }

  network_public_route_tables = {
    for idx, rt_id in module.network_vpc.public_route_table_ids : tostring(idx) => rt_id
  }

  business_private_route_tables = {
    for idx, rt_id in module.business_vpc.private_route_table_ids : tostring(idx) => rt_id
  }

  business_public_route_tables = {
    for idx, rt_id in module.business_vpc.public_route_table_ids : tostring(idx) => rt_id
  }
}

###############################################################################
# network-vpc
###############################################################################

module "network_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "${var.project_name}-network-vpc"
  cidr = var.network_vpc_cidr

  azs             = local.azs
  private_subnets = ["10.10.1.0/24", "10.10.2.0/24"]
  public_subnets  = ["10.10.101.0/24", "10.10.102.0/24"]

  enable_nat_gateway = false
  single_nat_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.common_tags
}

###############################################################################
# business-vpc
###############################################################################

module "business_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "${var.project_name}-business-vpc"
  cidr = var.business_vpc_cidr

  azs             = local.azs
  private_subnets = ["10.20.1.0/24", "10.20.2.0/24"]
  public_subnets  = ["10.20.101.0/24", "10.20.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.common_tags
}

###############################################################################
# IAM for SSM Session Manager
###############################################################################

resource "aws_iam_role" "ssm_role" {
  name = "${var.project_name}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "${var.project_name}-ec2-ssm-profile"
  role = aws_iam_role.ssm_role.name

  tags = local.common_tags
}

###############################################################################
# VPC Peering
###############################################################################

resource "aws_vpc_peering_connection" "network_to_business" {
  vpc_id      = module.network_vpc.vpc_id
  peer_vpc_id = module.business_vpc.vpc_id
  auto_accept = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-peering"
  })
}

# network-vpc -> business-vpc
resource "aws_route" "network_private_to_business" {
  for_each = local.network_private_route_tables

  route_table_id            = each.value
  destination_cidr_block    = var.business_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.network_to_business.id
}

resource "aws_route" "network_public_to_business" {
  for_each = local.network_public_route_tables

  route_table_id            = each.value
  destination_cidr_block    = var.business_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.network_to_business.id
}

# business-vpc -> network-vpc
resource "aws_route" "business_private_to_network" {
  for_each = local.business_private_route_tables

  route_table_id            = each.value
  destination_cidr_block    = var.network_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.network_to_business.id
}

resource "aws_route" "business_public_to_network" {
  for_each = local.business_public_route_tables

  route_table_id            = each.value
  destination_cidr_block    = var.network_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.network_to_business.id
}

# business-vpc -> client vpn cidr
resource "aws_route" "business_private_to_client_vpn" {
  for_each = local.vpn_enabled ? local.business_private_route_tables : {}

  route_table_id            = each.value
  destination_cidr_block    = var.client_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.network_to_business.id
}

resource "aws_route" "business_public_to_client_vpn" {
  for_each = local.vpn_enabled ? local.business_public_route_tables : {}

  route_table_id            = each.value
  destination_cidr_block    = var.client_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.network_to_business.id
}

###############################################################################
# Security Group for nginx EC2
###############################################################################

resource "aws_security_group" "business_nginx_sg" {
  name        = "${var.project_name}-business-nginx-sg"
  description = "Allow HTTP from internal networks"
  vpc_id      = module.business_vpc.vpc_id

  ingress {
    description = "HTTP from network-vpc for internal testing"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.network_vpc_cidr]
  }

  dynamic "ingress" {
    for_each = local.vpn_enabled ? [1] : []
    content {
      description = "HTTP from Client VPN clients"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = [var.client_cidr_block]
    }
  }

  egress {
    description = "all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

###############################################################################
# nginx EC2 in private subnet
###############################################################################

resource "aws_instance" "business_nginx" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = module.business_vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.business_nginx_sg.id]
  key_name               = var.key_name

  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  associate_public_ip_address = false
  user_data                   = file("${path.module}/user_data_nginx.sh")

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-business-nginx"
  })

  depends_on = [
    aws_iam_role_policy_attachment.ssm_core
  ]
}

###############################################################################
# Client VPN resources
###############################################################################

resource "aws_security_group" "client_vpn_sg" {
  count       = local.vpn_enabled ? 1 : 0
  name        = "${var.project_name}-client-vpn-sg"
  description = "Security group for Client VPN endpoint"
  vpc_id      = module.network_vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "client_vpn" {
  count             = local.vpn_enabled ? 1 : 0
  name              = "/aws/ec2/client-vpn/${var.project_name}"
  retention_in_days = 7

  tags = local.common_tags
}

resource "aws_cloudwatch_log_stream" "client_vpn" {
  count          = local.vpn_enabled ? 1 : 0
  name           = "connections"
  log_group_name = aws_cloudwatch_log_group.client_vpn[0].name
}

resource "aws_ec2_client_vpn_endpoint" "this" {
  count                  = local.vpn_enabled ? 1 : 0
  description            = "${var.project_name} Client VPN"
  server_certificate_arn = var.server_certificate_arn
  client_cidr_block      = var.client_cidr_block
  split_tunnel           = true
  vpc_id                 = module.network_vpc.vpc_id
  security_group_ids     = [aws_security_group.client_vpn_sg[0].id]

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = var.root_certificate_chain_arn
  }

  connection_log_options {
    enabled               = true
    cloudwatch_log_group  = aws_cloudwatch_log_group.client_vpn[0].name
    cloudwatch_log_stream = aws_cloudwatch_log_stream.client_vpn[0].name
  }

  dns_servers = ["8.8.8.8", "1.1.1.1"]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-client-vpn-endpoint"
  })
}

resource "aws_ec2_client_vpn_network_association" "network_assoc" {
  count                  = local.vpn_enabled ? 1 : 0
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this[0].id
  subnet_id              = module.network_vpc.private_subnets[0]
}

resource "aws_ec2_client_vpn_authorization_rule" "allow_network_vpc" {
  count                  = local.vpn_enabled ? 1 : 0
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this[0].id
  target_network_cidr    = var.network_vpc_cidr
  authorize_all_groups   = true

  depends_on = [aws_ec2_client_vpn_network_association.network_assoc]
}

resource "aws_ec2_client_vpn_authorization_rule" "allow_business_vpc" {
  count                  = local.vpn_enabled ? 1 : 0
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this[0].id
  target_network_cidr    = var.business_vpc_cidr
  authorize_all_groups   = true

  depends_on = [aws_ec2_client_vpn_network_association.network_assoc]
}

resource "aws_ec2_client_vpn_route" "to_business_vpc" {
  count                  = local.vpn_enabled ? 1 : 0
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this[0].id
  destination_cidr_block = var.business_vpc_cidr
  target_vpc_subnet_id   = module.network_vpc.private_subnets[0]
  description            = "Route to business-vpc"

  depends_on = [aws_ec2_client_vpn_network_association.network_assoc]
}