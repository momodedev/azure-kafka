
variable "subscription_id" {
  type    = string
  default = null

  validation {
    condition     = var.subscription_id != null && length(trimspace(var.subscription_id)) > 0
    error_message = "subscription_id must be set (via terraform.tfvars, -var, or environment)."
  }
}


variable "location" {
  type    = string
  default = "westus"
}

variable "resource_group_name" {
  type        = string
  description = "Resource Group name. Naming standard: mall."
  default     = "mall"
}

variable "name_prefix" {
  type        = string
  description = "Resource name prefix. Naming standard examples: rds-prod / es-prod / kafka-prod."
  default     = "rds-prod"
}

variable "resource_prefix" {
  type        = string
  description = "Optional override for resource name prefix. If set, it takes precedence over name_prefix."
  default     = null
}

variable "vm_count" {
  type    = number
  default = 3
}

variable "vm_size" {
  type    = string
  default = "Standard_D4s_v6"
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

variable "ssh_public_key" {
  type        = string
  description = "OpenSSH public key content, e.g. from ~/.ssh/id_rsa.pub"
}

variable "extra_ssh_public_keys" {
  type        = list(string)
  description = "Additional OpenSSH public keys to add to the VM admin user's authorized_keys (e.g. Ansible controller key)."
  default     = []
}

variable "enable_ansible_ssh_whitelist" {
  type        = bool
  description = "Whether to add an NSG rule that allows SSH (22) inbound from the Ansible server IP."
  default     = false

  validation {
    condition     = !var.enable_ansible_ssh_whitelist || var.ansible_server_private_ip != null
    error_message = "When enable_ansible_ssh_whitelist=true, you must set ansible_server_private_ip."
  }
}

variable "ansible_server_private_ip" {
  type        = string
  description = "Ansible server source IP/CIDR to whitelist for SSH. Example: 10.1.0.5/32"
  default     = null
}

variable "enable_jumpserver_vnet_peering" {
  type        = bool
  description = "Whether to create bidirectional VNet peering between this deployment VNet and an existing Jumpserver/Management VNet."
  default     = false

  validation {
    condition = (
      !var.enable_jumpserver_vnet_peering
      || (
        var.jumpserver_vnet_resource_group_name != null
        && var.jumpserver_vnet_name != null
      )
    )
    error_message = "When enable_jumpserver_vnet_peering=true, you must set jumpserver_vnet_resource_group_name and jumpserver_vnet_name."
  }
}

variable "jumpserver_vnet_resource_group_name" {
  type        = string
  description = "Resource group name of the Jumpserver VNet (e.g. rg-jumpserver)."
  default     = null
}

variable "jumpserver_vnet_name" {
  type        = string
  description = "VNet name of the Jumpserver (e.g. jumpserver-vnet)."
  default     = null
}

variable "vnet_cidr" {
  type    = string
  default = "172.16.0.0/16"
}

variable "subnet_cidr" {
  type    = string
  default = "172.16.1.0/24"
}

variable "enable_second_subnet" {
  type        = bool
  description = "Whether to create a second subnet (in the same VNet) and an optional second VM group."
  default     = false

  validation {
    condition = (
      !var.enable_second_subnet
      || (
        var.subnet2_cidr != null
        && var.vm_count_subnet2 > 0
      )
    )
    error_message = "When enable_second_subnet=true, you must set subnet2_cidr and vm_count_subnet2 must be > 0."
  }
}

variable "subnet2_cidr" {
  type        = string
  description = "Address prefix CIDR for subnet2 in the same VNet. Only used when enable_second_subnet=true."
  default     = null

  validation {
    condition     = var.subnet2_cidr == null || var.subnet2_cidr != var.subnet_cidr
    error_message = "subnet2_cidr must be different from subnet_cidr."
  }
}

variable "vm_count_subnet2" {
  type        = number
  description = "Number of VMs to create in subnet2 (same VNet). Only used when enable_second_subnet=true."
  default     = 0

  validation {
    condition     = var.vm_count_subnet2 >= 0
    error_message = "vm_count_subnet2 must be >= 0."
  }
}

variable "vm_size_subnet2" {
  type        = string
  description = "Optional VM size override for subnet2 VM group. If null, uses vm_size."
  default     = null
}

variable "internal_tcp_ports" {
  type = list(number)
  default = [
    22,
    3306,
    3000,
    9090,
    9092,
    9100,
    9104,
    9308,
    9200,
    9300
  ]
}

variable "pv2_data_disk" {
  type = object({
    size_gb         = number
    lun             = number
    caching         = string
    iops            = number
    throughput_mbps = number
  })

  default = {
    size_gb         = 512
    lun             = 0
    caching         = "None"
    iops            = 20000
    throughput_mbps = 900
  }
}

variable "os_disk_size_gb" {
  type    = number
  default = 64
}

variable "enable_auto_ansible_ssh_key" {
  type        = bool
  description = "When true, Terraform generates a dedicated SSH keypair for the Ansible controller -> MySQL nodes. Public key is added to all VMs; private key is written to the controller at ~/.ssh/id_ed25519. WARNING: the private key will be stored in Terraform state."
  default     = false
}

variable "enable_ansible_controller_vm" {
  type        = bool
  description = "Whether to create a dedicated Ansible controller VM in the same VNet/subnet as the MySQL VMs (avoids VNet peering)."
  default     = true
}

variable "ansible_controller_vm_name" {
  type        = string
  description = "VM name for the Ansible controller (only used when enable_ansible_controller_vm=true)."
  default     = "ansible-controller"
}

variable "ansible_controller_vm_size" {
  type        = string
  description = "VM size for the Ansible controller (only used when enable_ansible_controller_vm=true)."
  default     = "Standard_D2ads_v6"
}