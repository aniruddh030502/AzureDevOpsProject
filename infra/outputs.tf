output "traffic_manager_fqdn" {
  description = "The FQDN (Fully Qualified Domain Name) of the Azure Traffic Manager profile."
  value       = azurerm_traffic_manager_profile.main.fqdn # Change made here (line 3 in outputs.tf)
}

output "aks_active_public_ip" {
  description = "The public IP address created for AKS active (Central US) backend. This IP should be used by your AKS Ingress Controller Service."
  value       = azurerm_public_ip.aks_frontend_ip["centralus"].ip_address
}

output "aks_passive_public_ip" {
  description = "The public IP address created for AKS passive (West US 3) backend. This IP should be used by your AKS Ingress Controller Service."
  value       = azurerm_public_ip.aks_frontend_ip["westus3"].ip_address
}

output "aks_active_kubeconfig" {
  description = "The Kubeconfig for the active (Central US) AKS cluster. Use 'az aks get-credentials --resource-group <resource_group_name> --name aks-active-cluster --file ~/.kube/config --overwrite-existing' to configure kubectl."
  value       = azurerm_kubernetes_cluster.aks["centralus"].kube_config_raw
  sensitive   = true
}

output "aks_passive_kubeconfig" {
  description = "The Kubeconfig for the passive (West US 3) AKS cluster. Use 'az aks get-credentials --resource-group <resource_group_name> --name aks-passive-cluster --file ~/.kube/config --overwrite-existing' to configure kubectl."
  value       = azurerm_kubernetes_cluster.aks["westus3"].kube_config_raw
  sensitive   = true
}