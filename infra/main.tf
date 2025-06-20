provider "azurerm" {
  subscription_id="1674f375-e996-4423-bd25-e0e8f6e76d13"
  features {}
}

// Create a single resource group to contain all resources.
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.regions["centralus"].location
}

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

// Create two Standard SKU Public IP addresses. These IPs will now be directly
// assigned to the NGINX Ingress Controller's LoadBalancer service in each AKS cluster.
resource "azurerm_public_ip" "aks_frontend_ip" { # Renamed to better reflect its use
  for_each            = var.regions
  name                = "${each.value.aks_cluster_name}-frontend-ip"
  location            = each.value.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags = {
    purpose = "TrafficManagerEndpoint"
    region  = each.key
  }
}

// *** Removed Azure Front Door resources ***

// Create an Azure Traffic Manager Profile
resource "azurerm_traffic_manager_profile" "main" {
  name                   = "tm-aks-multi-region" # Must be globally unique
  resource_group_name    = azurerm_resource_group.main.name
  traffic_routing_method = "Performance" # Other options: Priority, Weighted, Geographic, MultiValue, Subnet

  dns_config {
    relative_name = "aks-multi-region-app" # The full FQDN will be <relative_name>.trafficmanager.net
    ttl           = 60
  }

  monitor_config {
    protocol                     = "HTTP" # Use HTTP or HTTPS for health checks
    port                         = 80      # Port where the health check should be sent (Ingress controller)
    path                         = "/"     # Path to probe (e.g., /healthz, or just / if NGINX responds)
    interval_in_seconds          = 30
    timeout_in_seconds           = 9
    tolerated_number_of_failures = 3
  }

  tags = {
    environment = "dev"
    project     = "MultiRegionAKS"
  }
}

// Create Traffic Manager Endpoints for each AKS cluster's Public IP
resource "azurerm_traffic_manager_external_endpoint" "aks_endpoint" {
  for_each            = var.regions
  name                = "${each.value.aks_cluster_name}-endpoint"
  profile_id          = azurerm_traffic_manager_profile.main.id
  weight              = 100 # Can be adjusted for weighted routing
  target              = azurerm_public_ip.aks_frontend_ip[each.key].ip_address
  always_serve_enabled = true # Keep serving traffic if all endpoints are unhealthy (optional)
  endpoint_location   = each.value.location
}

// Add Azure Container Registry (ACR)
// This will be created in the main resource group's location (Central US).
resource "azurerm_container_registry" "main_acr" {
  name                = "aksmultiregistry${random_string.suffix.result}" # Globally unique name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic" # Basic, Standard, or Premium
  admin_enabled       = true    # Enables admin user for easier push/pull (for testing/dev)

  tags = {
    environment = "dev"
    project     = "MultiRegionAKS"
  }
}

// Helper resource to generate a random string for ACR name uniqueness
resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
  numeric = true
}
