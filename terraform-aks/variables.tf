variable "resource_group_name" {}
variable "location" {}
variable "aks_cluster_name" {}
variable "node_count" {
  default = 2
}
variable "dns_prefix" {}
