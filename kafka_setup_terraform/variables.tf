variable "resource_group_location" {
  type        = string
  default     = "westus3"
  description = "Azure region for Kafka infrastructure (must support Premium SSD v2)."
}

variable "resource_group_name" {
  type        = string
  default     = "mall"
  description = "Name of the resource group that hosts Kafka resources (must be 'mall')."
}

variable "ARM_SUBSCRIPTION_ID" {
  description = "Azure subscription identifier."
  type        = string
  default = "8d6bd1eb-ae31-4f2c-856a-0f8e47115c4b"
}

variable "ARM_TENANT_ID" {
  description = "Azure tenant identifier."
  type        = string
  default = "16b3c013-d300-468d-ac64-7eda0820b6d3"
}

variable "kafka_vmss_name" {
  type        = string
  default     = "kafka-prod-brokers"
  description = "Virtual machine scale set name for Kafka brokers (kafka-prod-* prefix)."
}

variable "kafka_admin_username" {
  type        = string
  default     = "rockyadmin"
  description = "Admin username created on each Kafka instance."
}

variable "kafka_instance_count" {
  type        = number
  default     = 3
  description = "Number of Kafka broker instances to provision."
}

variable "kafka_vm_size" {
  type        = string
  default     = "Standard_D4s_v5"
  description = "Azure compute SKU for Kafka brokers."
}

variable "kafka_data_disk_size_gb" {
  type        = number
  default     = 256
  description = "Premium SSD v2 data disk size attached to each Kafka broker (GiB)."
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

variable "monitor_vm_name" {
  type        = string
  default     = "kafka-prod-monitor"
  description = "Hostname for the Prometheus/Grafana monitoring VM (kafka-prod-* prefix)."
}

variable "monitor_admin_username" {
  type        = string
  default     = "rockyadmin"
  description = "Admin username created on the monitoring VM."
}

variable "monitor_vm_size" {
  type        = string
  default     = "Standard_D2s_v5"
  description = "Azure compute SKU for the monitoring VM."
}