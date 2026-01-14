terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.1.0"  # CONFIRM: Must be >=4.0.0
    }
  }
}
provider "azapi" {
}
# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
  use_msi = true
  subscription_id = var.ARM_SUBSCRIPTION_ID
}