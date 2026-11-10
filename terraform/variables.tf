# =============================================================================
# Input Variables
# Values provided via environments/*.tfvars — NEVER hardcode defaults for
# version-sensitive or region-sensitive values (K8s version, location)
# =============================================================================

variable "project_name" {
  description = "Project identifier used in resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging)"
  type        = string
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  # No default — must be explicit in tfvars
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version — ALWAYS verify before apply: az aks get-versions --location centralindia"
  type        = string
  # No default — versions deprecate. Must be set in tfvars and verified per run.
}

variable "node_count" {
  description = "Number of AKS worker nodes"
  type        = number
  default     = 1
}

variable "node_vm_size" {
  description = "AKS node VM SKU — B2s for non-prod (FinOps: right-sized, ~$0.04/hr)"
  type        = string
  default     = "Standard_B2s"
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB — 30GB is minimum viable (FinOps: no overprovisioning)"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Resource tags for cost attribution and lifecycle management"
  type        = map(string)
  default     = {}
}