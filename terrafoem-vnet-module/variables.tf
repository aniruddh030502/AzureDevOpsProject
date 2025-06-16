variable "resource_group_name" {
  description = "Name of the resource group" 
  type        = string
}

variable "location" {
  description = "Azure location" 
  type        = string
  default     = "East US"
}

variable "vnet_name" {
  description = "Name of the Virtual Network"
  type        = string
}

variable "address_space" {
  description = "Address space for the VNet"
  type        = list(string)
}

variable "public_subnet_name" {
  description = "Name of the public subnet"
  type        = string
}

variable "public_subnet_prefix" {
  description = "CIDR prefix for public subnet"
  type        = string
}

variable "private_subnet_name" {
  description = "Name of the private subnet"
  type        = string
}

variable "private_subnet_prefix" {
  description = "CIDR prefix for private subnet"
  type        = string
}

variable "bastion_subnet_prefix" {
  description = "CIDR prefix for Bastion subnet"
  type        = string
}
