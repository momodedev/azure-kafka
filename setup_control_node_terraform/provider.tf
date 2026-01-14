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

provider "azurerm" {
  features {
    key_vault {
      purge_soft_deleted_secrets_on_destroy = true
      recover_soft_deleted_secrets          = true
    }
  }
  subscription_id = var.ARM_SUBSCRIPTION_ID
}