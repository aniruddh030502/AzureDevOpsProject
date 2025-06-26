variable "resource_group_name" {
  description = "The name of the resource group to create all resources in."
  type        = string
  default     = "rg-aks-aniruddha" // Updated default resource group name for active region
}

variable "regions" {
  description = "A map of regions, their locations, and associated network configurations, including AKS details."
  type = map(object({
    location            = string
    vnet_address_space  = list(string)
    public_subnet_cidr  = list(string)
    private_subnet_cidr = list(string)
    aks_cluster_name    = string // Added AKS cluster name per region
    dns_prefix          = string // Added DNS prefix per region
    vm_size             = string // Added VM size per region
  }))
  default = {
    "centralus" = {
      location            = "southeastasia"
      vnet_address_space  = ["10.0.0.0/16"]
      public_subnet_cidr  = ["10.0.1.0/24"]
      private_subnet_cidr = ["10.0.2.0/24"]
      aks_cluster_name    = "aks-active-cluster"
      dns_prefix          = "aksactive"
      vm_size             = "Standard_A2_v2"
    },
    "westus3" = {
      location            = "indonesiacentral"
      vnet_address_space  = ["10.1.0.0/16"]
      public_subnet_cidr  = ["10.1.1.0/24"]
      private_subnet_cidr = ["10.1.2.0/24"]
      aks_cluster_name    = "aks-passive-cluster"
      dns_prefix          = "akspassive"
      vm_size             = "Standard_A2_v2"
    }
  }
}

variable "aks_kubernetes_version" {
  description = "The Kubernetes version to use for the AKS clusters."
  type        = string
  default     = "1.30.6"
}

variable "aks_node_count" {
  description = "The number of nodes in the AKS node pools for each cluster."
  type        = number
  default     = 1
}

variable "on_prem_vnet_address_space" {
  description = "The address space for the simulated on-premises network."
  type        = list(string)
  default     = ["192.168.0.0/16"]
}

variable "on_prem_gateway_subnet_cidr" {
  description = "The CIDR for the GatewaySubnet in the simulated on-premises VNet."
  type        = list(string)
  default     = ["192.168.254.0/27"] # /27 is minimum for GatewaySubnet
}

variable "on_prem_network_address_space" {
  description = "The specific subnet CIDR for the 'on-prem' network that will be advertised over VPN."
  type        = list(string)
  default     = ["192.168.1.0/24"] # Example subnet within on_prem_vnet_address_space
}

variable "on_prem_local_gateway_ip_address" {
  description = "A dummy public IP address to represent the on-premises VPN device (for Local Network Gateway)."
  type        = string
  default     = "203.0.113.10" # Example public IP - must be a valid public IP format
}

variable "existing_acr_name" {
  description = "The name of your existing Azure Container Registry."
  type        = string
  default     = "aksmultiregistryani" # <<< IMPORTANT: UPDATE THIS TO YOUR ACR NAME
}

variable "existing_acr_resource_group" {
  description = "The resource group name of your existing Azure Container Registry."
  type        = string
  default     = "rg-aks-active" # <<< IMPORTANT: UPDATE THIS TO YOUR ACR RESOURCE GROUP
}
