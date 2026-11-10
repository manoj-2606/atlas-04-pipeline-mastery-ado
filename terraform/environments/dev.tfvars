# =============================================================================
# Dev Environment — PRIMARY environment for P4
# This is the only tfvars used in the pipeline.
# Staging deploys to the same cluster, different Helm namespace.
# =============================================================================

project_name       = "atlas-04"
environment        = "dev"
location           = "centralindia"
kubernetes_version = "1.34" # VERIFY: az aks get-versions --location centralindia --output table

# FinOps: Right-sized for portfolio demo
node_count      = 1
node_vm_size    = "Standard_B2s" # ~$0.04/hr — cheapest viable for AKS
os_disk_size_gb = 30             # Minimum viable — no overprovisioning

# FinOps: Every resource tagged for cost attribution
tags = {
  project     = "atlas-04-pipeline-mastery-ado"
  environment = "dev"
  team        = "platform"
  cost-center = "atlas-portfolio"
  created-by  = "terraform"
  managed-by  = "azure-devops"
  destroy-by  = "end-of-day"
}