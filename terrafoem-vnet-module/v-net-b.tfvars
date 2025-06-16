resource_group_name    = "rg-vnet-b"
location               = "East US"
vnet_name              = "vnet-b"
address_space          = ["10.20.0.0/16"]

public_subnet_name     = "vnet-b-public"
public_subnet_prefix   = "10.20.1.0/24"

private_subnet_name    = "vnet-b-private"
private_subnet_prefix  = "10.20.2.0/24"

bastion_subnet_prefix  = "10.20.3.0/27"
