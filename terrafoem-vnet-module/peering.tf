resource "azurerm_virtual_network_peering" "peer_a_to_b" {
  name                      = "peer-a-to-b"
  resource_group_name       = azurerm_virtual_network.vnet_a.resource_group_name
  virtual_network_name      = azurerm_virtual_network.vnet_a.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_b.id

  allow_forwarded_traffic = true
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "peer_b_to_a" {
  name                      = "peer-b-to-a"
  resource_group_name       = azurerm_virtual_network.vnet_b.resource_group_name
  virtual_network_name      = azurerm_virtual_network.vnet_b.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_a.id

  allow_forwarded_traffic = true
  allow_virtual_network_access = true
}
