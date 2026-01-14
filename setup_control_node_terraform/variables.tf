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

variable "kafka_instance_count" {
  description = "Number of Kafka broker instances to provision in the VMSS."
  type        = number
  default     = 3
}

variable "kafka_data_disk_iops" {
  description = "Provisioned IOPS for Kafka data disk (Premium SSD v2)."
  type        = number
  default     = 3000
}

variable "kafka_data_disk_throughput_mbps" {
  description = "Provisioned throughput (MB/s) for Kafka data disk (Premium SSD v2)."
  type        = number
  default     = 125
}

variable "kafka_vm_size" {
  description = "Azure VM size for Kafka brokers."
  type        = string
  default     = "Standard_D8s_v5"
}


