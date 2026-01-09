variable "resource_group_location" {
  default     = "westus3"
  description = "Location of the resource group."
}

variable "resource_group_name" {
  default     = "control_rg"
  description = "Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription."
}

variable "github_token" {
  description = "github read token"
  type        = string
  sensitive   = true
}


variable "ARM_SUBSCRIPTION_ID" {
  description = "subscription id"
  type        = string
}

variable "tf_cmd_type" {
  description = "terraform command"
  type        = string
}


