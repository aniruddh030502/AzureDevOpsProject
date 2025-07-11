provider "azurerm" {
  subscription_id=""
  features {}
}

// Create a single resource group to contain all resources.
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.regions["centralus"].location
}

// --- Removed Resources for Terraform Remote State as they are pre-existing ---
# resource "azurerm_storage_account" "tfstate_storage" {
#   name                     = "akstfstatestorage001"
#   resource_group_name      = azurerm_resource_group.main.name
#   location                 = azurerm_resource_group.main.location
#   account_tier             = "Standard"
#   account_replication_type = "LRS"
#   min_tls_version          = "TLS1_2"
#
#   tags = {
#     environment = "dev"
#     purpose     = "terraform-state"
#   }
# }
#
# resource "azurerm_storage_container" "tfstate_container" {
#   name                  = "tfstate"
#   storage_account_name  = azurerm_storage_account.tfstate_storage.name
#   container_access_type = "private"
# }
# --- End Removed Remote State Resources ---


// Loop through the defined regions to create Virtual Networks.
resource "azurerm_virtual_network" "vnet" {
  for_each            = var.regions
  name                = "vnet-${replace(each.key, " ", "")}"
  location            = each.value.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = each.value.vnet_address_space
}

// Create a public subnet within each Virtual Network.
resource "azurerm_subnet" "public" {
  for_each             = var.regions
  name                 = "subnet-public-${replace(each.key, " ", "")}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet[each.key].name
  address_prefixes     = each.value.public_subnet_cidr
}

// Create a private subnet within each Virtual Network.
resource "azurerm_subnet" "private" {
  for_each             = var.regions
  name                 = "subnet-private-${replace(each.key, " ", "")}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet[each.key].name
  address_prefixes     = each.value.private_subnet_cidr
}

// --- Network Security Group (NSG) for Public Subnets ---
resource "azurerm_network_security_group" "public_subnet_nsg" {
  for_each            = var.regions
  name                = "nsg-${replace(each.key, " ", "")}-public"
  location            = each.value.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "Allow_HTTP_Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*" # Allow from any IP (for external access)
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow_HTTPS_Inbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*" # Allow from any IP (for external access)
    destination_address_prefix = "*"
  }

  tags = {
    environment = "dev"
    purpose     = "public-subnet-traffic-control"
  }
}

resource "azurerm_subnet_network_security_group_association" "public_subnet_nsg_association" {
  for_each                = var.regions
  subnet_id               = azurerm_subnet.public[each.key].id
  network_security_group_id = azurerm_network_security_group.public_subnet_nsg[each.key].id
}
# --- End NSG ---


// Create an Azure Kubernetes Service (AKS) cluster in each region.
resource "azurerm_kubernetes_cluster" "aks" {
  for_each            = var.regions
  name                = each.value.aks_cluster_name
  location            = each.value.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = each.value.dns_prefix
  kubernetes_version  = var.aks_kubernetes_version

  default_node_pool {
    name                 = "default"
    node_count           = var.aks_node_count
    vm_size              = each.value.vm_size
    vnet_subnet_id       = azurerm_subnet.private[each.key].id
    max_pods             = 30
    # Added for node pool updates that require rotation
    temporary_name_for_rotation = "temp${random_string.suffix.result}"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin     = "azure"
    dns_service_ip     = cidrhost(cidrsubnet(each.value.vnet_address_space[0], 8, 200), 10)
    service_cidr       = cidrsubnet(each.value.vnet_address_space[0], 8, 200)
  }

  role_based_access_control_enabled = true

  tags = {
    environment = "dev"
    region      = each.key
  }
}

// Create two Standard SKU Public IP addresses.
// THESE ARE NOW CREATED IN THE AKS NODE RESOURCE GROUP for better integration.
resource "azurerm_public_ip" "aks_frontend_ip" {
  for_each            = var.regions
  name                = "${each.value.aks_cluster_name}-frontend-ip"
  # Set resource_group_name to the AKS-managed node resource group
  resource_group_name = azurerm_kubernetes_cluster.aks[each.key].node_resource_group
  location            = each.value.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags = {
    purpose = "TrafficManagerEndpoint"
    region  = each.key
  }
}


// Create an Azure Traffic Manager Profile
resource "azurerm_traffic_manager_profile" "main" {
  name                   = "tm-aks-multi-region" # Must be globally unique
  resource_group_name    = azurerm_resource_group.main.name
  traffic_routing_method = "Performance"

  dns_config {
    relative_name = "aks-multi-region-app"
    ttl           = 60
  }

  monitor_config {
    protocol                     = "HTTP"
    port                         = 8080
    path                         = "/" # Ensure your NGINX Ingress Controller responds with 200 OK on this path
    interval_in_seconds          = 30
    timeout_in_seconds           = 9
    tolerated_number_of_failures = 3
  }

  tags = {
    environment = "dev"
    project     = "MultiRegionAKS"
  }
}

// Create Traffic Manager Endpoints for each AKS clusters Public IP

resource "azurerm_traffic_manager_external_endpoint" "aks_endpoint" {
  for_each            = var.regions
  name                = "${each.value.aks_cluster_name}-endpoint"
  profile_id          = azurerm_traffic_manager_profile.main.id
  weight              = 100
  target              = azurerm_public_ip.aks_frontend_ip[each.key].ip_address
  always_serve_enabled = true
  endpoint_location   = each.value.location
}

// Add Azure Container Registry (ACR)
// resource "azurerm_container_registry" "main_acr" {
//   name                = "aksmultiregistryanihhk" # Globally unique name
//   resource_group_name = azurerm_resource_group.main.name
//   location            = azurerm_resource_group.main.location
//   sku                 = "Basic"
//   admin_enabled       = true

//   tags = {
//     environment = "dev"
//     project     = "MultiRegionAKS"
//   }
// }

// Helper resource to generate a random string for ACR name uniqueness (for random names)
resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
  numeric = true
}


resource "azurerm_key_vault" "main_keyvault" {
  name                     = "kv-aks-multiregion-${random_string.suffix.result}" # Globally unique name
  location                 = azurerm_resource_group.main.location
  resource_group_name      = azurerm_resource_group.main.name
  tenant_id                = data.azurerm_client_config.current.tenant_id
  sku_name                 = "standard"
  soft_delete_retention_days = 7 # Minimum 7 days
  purge_protection_enabled   = false

  tags = {
    environment = "dev"
    purpose     = "application-secrets"
  }
}

data "azurerm_client_config" "current" {} # Get current client's tenant_id

# Grant AKS Managed Identity 'Get' permission on secrets in Key Vault
resource "azurerm_key_vault_access_policy" "aks_keyvault_policy" {
  key_vault_id = azurerm_key_vault.main_keyvault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_kubernetes_cluster.aks["centralus"].identity[0].principal_id # Use one AKS cluster's identity

  secret_permissions = [
    "Get", # Allow AKS applications to retrieve secrets
  ]
}

# Store the primary access key of the tfstate storage account in Key Vault
# NOTE: The identity running Terraform must have 'Set' permission on secrets in Key Vault for this to work.
# NOTE: This resource is now commented out as it relies on the storage account being managed by Terraform
# If you still want to store the key in Key Vault, you'll need to manually retrieve the key
# for "aniruddhastorage01" and define it as a local or variable, then reference that.
# For example:
# locals {
#   aniruddha_storage_key = "YOUR_MANUALLY_RETRIEVED_STORAGE_KEY"
# }
# resource "azurerm_key_vault_secret" "tfstate_storage_key" {
#   name         = "tfstate-storage-primary-key"
#   value        = local.aniruddha_storage_key
#   key_vault_id = azurerm_key_vault.main_keyvault.id
#
#   tags = {
#     purpose = "terraform-state-access"
#   }
# }
# --- End Key Vault ---


# --- VNet Peering between active and passive AKS VNets ---
resource "azurerm_virtual_network_peering" "centralus_to_westus3_peering" {
  name                         = "vnet-peering-centralus-to-westus3"
  resource_group_name          = azurerm_resource_group.main.name
  virtual_network_name         = azurerm_virtual_network.vnet["centralus"].name
  remote_virtual_network_id    = azurerm_virtual_network.vnet["westus3"].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "westus3_to_centralus_peering" {
  name                         = "vnet-peering-westus3-to-centralus"
  resource_group_name          = azurerm_resource_group.main.name
  virtual_network_name         = azurerm_virtual_network.vnet["westus3"].name
  remote_virtual_network_id    = azurerm_virtual_network.vnet["centralus"].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
# --- End VNet Peering ---


# --- Simulated On-Premises Network (VNet and Site-to-Site VPN) ---

# 1. Create a VNet to represent the On-Premises Network
resource "azurerm_virtual_network" "on_prem_vnet" {
  name                = "vnet-onprem"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.on_prem_vnet_address_space

  tags = {
    environment = "dev"
    purpose     = "simulated-on-prem"
  }
}

# 2. Create the GatewaySubnet within the On-Prem VNet
resource "azurerm_subnet" "on_prem_gateway_subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.on_prem_vnet.name
  address_prefixes     = var.on_prem_gateway_subnet_cidr
}

# 3. Create a GatewaySubnet inside the AKS VNet (centralus)
resource "azurerm_subnet" "aks_gateway_subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet["centralus"].name
  address_prefixes     = ["10.0.3.0/27"] # Small subnet not overlapping others
}

# 4. Create a Public IP for the Azure VPN Gateway (in AKS VNet)
resource "azurerm_public_ip" "vnet_gateway_ip" {
  name                = "vnet-gateway-public-ip-centralus"
  location            = azurerm_virtual_network.vnet["centralus"].location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Dynamic"
  sku                 = "Basic"
}

# 5. Create the Azure VPN Gateway in the AKS VNet (centralus)
resource "azurerm_virtual_network_gateway" "centralus_vpn_gateway" {
  name                = "vnet-gateway-centralus"
  location            = azurerm_virtual_network.vnet["centralus"].location
  resource_group_name = azurerm_resource_group.main.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "Basic"

  ip_configuration {
    name                          = "vnetGatewayIpConfig"
    public_ip_address_id          = azurerm_public_ip.vnet_gateway_ip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.aks_gateway_subnet.id
  }

  tags = {
    environment = "dev"
    purpose     = "vpn-gateway"
  }
}

# 6. Create the Local Network Gateway (on-prem simulation)
resource "azurerm_local_network_gateway" "on_prem_local_gateway" {
  name                = "local-gateway-onprem"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  gateway_address     = var.on_prem_local_gateway_ip_address
  address_space       = var.on_prem_network_address_space

  tags = {
    environment = "dev"
    purpose     = "simulated-on-prem-gateway"
  }
}

# 7. Create the Site-to-Site VPN Connection
resource "azurerm_virtual_network_gateway_connection" "s2s_connection" {
  name                        = "s2s-vpn-connection-centralus-onprem"
  location                    = azurerm_resource_group.main.location
  resource_group_name         = azurerm_resource_group.main.name
  type                        = "IPsec"
  virtual_network_gateway_id  = azurerm_virtual_network_gateway.centralus_vpn_gateway.id
  local_network_gateway_id    = azurerm_local_network_gateway.on_prem_local_gateway.id
  shared_key                  = "MySharedKey"

  tags = {
    environment = "dev"
    purpose     = "s2s-vpn"
  }
}
# --- End Simulated On-Premises Network ---


# --- Azure Monitor: enabled_log Analytics Workspace and Diagnostic Settings ---
resource "azurerm_log_analytics_workspace" "main_log_workspace" {
  name                ="log-aks-multiregion-${random_string.suffix.result}" # Unique name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018" # Or "Free", "Standard", etc.
  retention_in_days   = 30 # Retention configured here for all ingested enabled_logs

  tags = {
    environment = "dev"
    purpose     = "centralized-enabled_logging"
  }
}

# Diagnostic settings for AKS Clusters
resource "azurerm_monitor_diagnostic_setting" "aks_diagnostic_setting" {
  for_each            = var.regions
  name                = "${each.value.aks_cluster_name}-diagnostics"
  target_resource_id  = azurerm_kubernetes_cluster.aks[each.key].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main_log_workspace.id

  enabled_metric {
    category = "AllMetrics"
  }

  enabled_log {
    category_group = "alllogs" # Collects all available control plane enabled_logs for AKS
  }
}

# Diagnostic settings for ACR
// resource "azurerm_monitor_diagnostic_setting" "acr_diagnostic_setting" {
//   name                       = "acr-diagnostics"
//   target_resource_id         = azurerm_container_registry.main_acr.id
//   log_analytics_workspace_id = azurerm_log_analytics_workspace.main_log_workspace.id

//   enabled_metric {
//     category = "AllMetrics"
//   }

//   enabled_log {
//     category = "ContainerRegistryloginEvents"
//   }
//   enabled_log {
//     category = "ContainerRegistryRepositoryEvents"
//   }
// }

# Diagnostic settings for Key Vault
resource "azurerm_monitor_diagnostic_setting" "keyvault_diagnostic_setting" {
  name                       = "keyvault-diagnostics"
  target_resource_id         = azurerm_key_vault.main_keyvault.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main_log_workspace.id

  enabled_metric {
    category = "AllMetrics"
  }

  enabled_log {
    category = "AuditEvent" # Audit enabled_logs for Key Vault operations
  }
}

# Diagnostic settings for Public IPs (only metrics are typically collected)
resource "azurerm_monitor_diagnostic_setting" "public_ip_diagnostic_setting" {
  for_each                   = azurerm_public_ip.aks_frontend_ip
  name                       = "${each.value.name}-diagnostics"
  target_resource_id         = each.value.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main_log_workspace.id

  enabled_metric {
    category = "AllMetrics"
  }
}

# Diagnostic settings for NSGs (only metrics for general events; flow enabled_logs are separate)
# resource "azurerm_monitor_diagnostic_setting" "nsg_diagnostic_setting" {
#   for_each                   = azurerm_network_security_group.public_subnet_nsg
#   name                       = "${each.value.name}-diagnostics"
#   target_resource_id         = each.value.id
#   log_analytics_workspace_id = azurerm_log_analytics_workspace.main_log_workspace.id

#   enabled_metric {
#     category = "AllMetrics"
#   }
# }

# Diagnostic settings for Traffic Manager Profile (only metrics are typically collected)
resource "azurerm_monitor_diagnostic_setting" "traffic_manager_diagnostic_setting" {
  name                       = "traffic-manager-diagnostics"
  target_resource_id         = azurerm_traffic_manager_profile.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main_log_workspace.id

  enabled_metric {
    category = "AllMetrics" # This includes ProbeHealthStatus as a metric
  }
}

# Diagnostic settings for Azure VPN Gateway (sends gateway-specific enabled_logs and metrics)
resource "azurerm_monitor_diagnostic_setting" "vpn_gateway_diagnostic_setting" {
  name                       = "vpn-gateway-diagnostics"
  target_resource_id         = azurerm_virtual_network_gateway.centralus_vpn_gateway.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main_log_workspace.id

  enabled_metric {
    category = "AllMetrics"
  }

  enabled_log {
    category = "GatewayDiagnosticLog"
  }
  enabled_log {
    category = "TunnelDiagnosticLog"
  }
  enabled_log {
    category = "RouteDiagnosticLog"
  }
  enabled_log {
    category = "IKEDiagnosticLog"
  }
}
