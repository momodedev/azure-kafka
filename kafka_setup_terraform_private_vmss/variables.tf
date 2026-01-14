variable "resource_group_location" {
  type        = string
  default     = "westus3"
  description = "Azure region that supports Premium SSD v2 for the Kafka deployment."
}

variable "resource_group_name" {
  type        = string
  default     = "mall"
  description = "Name of the resource group hosting the Kafka infrastructure resources (must be 'mall')."
}

variable "ARM_SUBSCRIPTION_ID" {
  description = "Azure subscription identifier used for deployment."
  type        = string
}

variable "kafka_vmss_name" {
  type        = string
  default     = "kafka-prod-brokers"
  description = "Name assigned to the Kafka broker virtual machine scale set (kafka-prod-* prefix)."
}

variable "kafka_admin_username" {
  type        = string
  default     = "rockyadmin"
  description = "Admin username provisioned on the Kafka broker instances."
}

variable "kafka_instance_count" {
  type        = number
  default     = 3
  description = "Number of Kafka broker instances to provision in the scale set."
}

variable "kafka_vm_size" {
  type        = string
  default     = "Standard_D4s_v5"
  description = "Azure compute SKU for Kafka brokers (x64, Premium SSD v2 capable in most regions)."
}

variable "kafka_data_disk_size_gb" {
  type        = number
  default     = 1024  # Changed from 256 to get P30 tier (5000 IOPS, 200 MB/s)
  description = "Capacity, in GiB, of the Premium SSD data disk attached to each broker instance."
}

variable "kafka_data_disk_iops" {
  type        = number
  default     = 3000
  description = "Provisioned IOPS for Premium SSD v2 data disk (3000-80000, must be >= 3 IOPS per GiB)."
}

variable "kafka_data_disk_throughput_mbps" {
  type        = number
  default     = 125
  description = "Provisioned throughput (MB/s) for Premium SSD v2 data disk (125-1200, must be >= 0.25 MB/s per provisioned IOPS)."
}