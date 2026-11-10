# =============================================================================
# Outputs — Published as pipeline artifact (tf-outputs.json)
# Downstream stages (Build, Deploy) download this artifact instead of
# re-running terraform init + output. Eliminates 2 redundant init calls.
# =============================================================================

output "resource_group_name" {
  description = "Resource group containing all project resources"
  value       = module.infra.resource_group_name
}

output "acr_login_server" {
  description = "ACR login server URL (e.g., acratlas04dev.azurecr.io)"
  value       = module.infra.acr_login_server
}

output "acr_name" {
  description = "ACR name for az acr login command"
  value       = module.infra.acr_name
}

output "aks_cluster_name" {
  description = "AKS cluster name for az aks get-credentials"
  value       = module.infra.aks_cluster_name
}

output "kube_config_raw" {
  description = "Raw kubeconfig — sensitive, not included in artifact"
  value       = module.infra.kube_config_raw
  sensitive   = true
}