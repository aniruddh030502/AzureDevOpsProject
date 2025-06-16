resource_group_name    = "rg-vnet-a"
location               = "East US"
vnet_name              = "vnet-a"
address_space          = ["10.10.0.0/16"]

public_subnet_name     = "vnet-a-public"
public_subnet_prefix   = "10.10.1.0/24"

private_subnet_name    = "vnet-a-private"
private_subnet_prefix  = "10.10.2.0/24"

bastion_subnet_prefix  = "10.10.3.0/27"
