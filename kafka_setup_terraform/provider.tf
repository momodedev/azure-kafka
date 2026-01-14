terraform {
  required_providers {
    azurerm = "~> 4.5"
    azapi   = {
      source  = "Azure/azapi"
      version = ">= 2.8"
    }
  }
}

provider "azapi" {}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
  subscription_id = var.ARM_SUBSCRIPTION_ID
  tenant_id       = var.ARM_TENANT_ID
}