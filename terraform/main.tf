# =============================================================================
# Atlas-04 Pipeline Mastery — Root Module
# Uses atlas-infra-base module for AKS + ACR provisioning
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.14"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-atlas-tfstate"
    storage_account_name = "atlastfstate2606"
    container_name       = "tfstate"
    key                  = "atlas-04.tfstate"
    use_oidc             = true
  }
}

provider "azurerm" {
  features {}
  use_oidc = true
}

# -----------------------------------------------------------------------------
# Infrastructure Module
# Source: github.com/manoj-2606/atlas-infra-base
# Provisions: Resource Group, VNet, AKS (1 node B2s), ACR (Basic)
# -----------------------------------------------------------------------------
module "infra" {
  source = "git::https://github.com/manoj-2606/atlas-infra-base.git"

  project_name           = var.project_name
  environment            = var.environment
  location               = var.location
  aks_kubernetes_version = var.kubernetes_version
  aks_node_count         = var.node_count
  aks_node_size          = var.node_vm_size
}