variable "aws_region" {
  type    = string
  default = "ap-northeast-1"
}

variable "project_name" {
  type    = string
  default = "henry-vpn-lab"
}

variable "network_vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "business_vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "client_cidr_block" {
  type    = string
  default = "172.16.0.0/22"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "key_name" {
  type    = string
  default = null
}

variable "enable_vpn" {
  type    = bool
  default = false
}

variable "server_certificate_arn" {
  type    = string
  default = null
}

variable "root_certificate_chain_arn" {
  type    = string
  default = null
}