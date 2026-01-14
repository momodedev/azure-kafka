terraform {

  required_providers {
    azurerm = "~> 4.5"
    azapi = ">= 2.8"
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