terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.1.0"
    }
  }
}
provider "azapi" {
}
# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {
    key_vault {
      purge_soft_deleted_secrets_on_destroy = true
      recover_soft_deleted_secrets          = true
    }
  }
  subscription_id = var.ARM_SUBSCRIPTION_ID
}