# =============================================================================
# Staging Environment — EXISTS TO SHOW THE PATTERN
#
# In production: staging would be a separate AKS cluster (separate RG, VNet,
# node pool config). Terraform apply with this file provisions isolated infra.
#
# In this portfolio demo: staging deploys to the SAME AKS cluster as dev,
# using a different Helm namespace (staging) and values-staging.yaml.
# This keeps cost under ₹100 while demonstrating multi-env promotion.
#
# This file is NOT used by the pipeline — it exists for completeness.
# =============================================================================

project_name       = "atlas-04"
environment        = "staging"
location           = "centralindia"
kubernetes_version = "1.34" # VERIFY: az aks get-versions --location centralindia --output table

node_count      = 1
node_vm_size    = "Standard_B2s"
os_disk_size_gb = 30

tags = {
  project     = "atlas-04-pipeline-mastery-ado"
  environment = "staging"
  team        = "platform"
  cost-center = "atlas-portfolio"
  created-by  = "terraform"
  managed-by  = "azure-devops"
  destroy-by  = "end-of-day"
}