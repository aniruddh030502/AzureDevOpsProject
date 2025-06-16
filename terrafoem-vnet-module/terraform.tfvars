resource_group_name    = "rg-demo" //edit
location               = "East US" //edit
vnet_name              = "vnet-demo"  //edit

# CIDR block for the VNet
address_space          = ["10.0.0.0/16"]

# Public Subnet
public_subnet_name     = "public-subnet"
public_subnet_prefix   = "10.0.1.0/24"

# Private Subnet
private_subnet_name    = "private-subnet"
private_subnet_prefix  = "10.0.2.0/24"

# Bastion Host Subnet
bastion_subnet_prefix  = "10.0.3.0/27"
