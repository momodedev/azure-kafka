###################### VMSS #####################


resource "azurerm_linux_virtual_machine_scale_set" "brokers" {
  name                = var.kafka_vmss_name
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  sku                 = var.kafka_vm_size
  instances           = var.kafka_instance_count
  upgrade_mode        = "Manual"
  computer_name_prefix = "kafka-prod"
  overprovision       = false
  orchestration_mode  = "Flexible"
  platform_fault_domain_count = 1

  source_image_reference {
    publisher = "resf"
    offer     = "rockylinux-x86_64"
    sku       = "9-base"
    version   = "9.6.20250531"
  }

  plan {
    publisher = "resf"
    product   = "rockylinux-x86_64"
    name      = "9-base"
  }

  admin_username = var.kafka_admin_username

  admin_ssh_key {
    username   = var.kafka_admin_username
    public_key = file(pathexpand("~/.ssh/id_rsa.pub"))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  network_interface {
    name                      = "kafka-prod-nic"
    primary                   = true
    network_security_group_id = azurerm_network_security_group.example.id

    ip_configuration {
      name      = "kafka-prod-ip-config"
      primary   = true
      subnet_id = azurerm_subnet.kafka.id
    }
  }

  boot_diagnostics {
    storage_account_uri = null
  }
}


data "azurerm_virtual_machine_scale_set" "brokers" {
  name                = azurerm_linux_virtual_machine_scale_set.brokers.name
  resource_group_name = azurerm_resource_group.example.name
}


output "kafka_private_ips" {
  description = "Private IP addresses assigned to Kafka brokers."
  value       = data.azurerm_virtual_machine_scale_set.brokers.instances.*.private_ip_address
}


resource "null_resource" "launch_ansible_playbook" {
  triggers = {
    private_ips = join(",", data.azurerm_virtual_machine_scale_set.brokers.instances.*.private_ip_address)
  }

  provisioner "local-exec" {
    working_dir = "../install_kafka_with_ansible_roles"
    command      = "mkdir -p generated && ./inventory_script_hosts.sh ${azurerm_resource_group.example.name} ${azurerm_linux_virtual_machine_scale_set.brokers.name} ${var.kafka_admin_username} > generated/kafka_hosts && ansible-playbook -i generated/kafka_hosts deploy_kafka_playbook.yaml && ansible-playbook -i monitoring/generated_inventory.ini monitoring/deploy_monitoring_playbook.yml"
  }
}


resource "azapi_resource" "kafka_data_disk" {
  count     = var.kafka_instance_count
  type      = "Microsoft.Compute/disks@2024-03-02"
  name      = "kafka-data-disk-${count.index}"
  location  = azurerm_resource_group.example.location
  parent_id = azurerm_resource_group.example.id

  body = {
    sku = {
      name = "PremiumV2_LRS"
    }
    properties = {
      diskSizeGB           = var.kafka_data_disk_size_gb
      diskIOPSReadWrite    = var.kafka_data_disk_iops
      diskMBpsReadWrite    = var.kafka_data_disk_throughput_mbps
      creationData = {
        createOption = "Empty"
      }
    }
  }
}


resource "azapi_resource_action" "attach_data_disk" {
  count       = var.kafka_instance_count
  resource_id = "${azurerm_linux_virtual_machine_scale_set.brokers.id}/virtualMachines/${count.index}"
  type        = "Microsoft.Compute/virtualMachineScaleSets/virtualMachines@2025-04-01"
  action      = "attachDetachDataDisks"
  method      = "POST"

  body = {
    dataDisksToAttach = [
      {
        diskId  = azapi_resource.kafka_data_disk[count.index].id
        lun     = 0
        caching = "None"
      }
    ]
    dataDisksToDetach = []
  }

  depends_on = [azapi_resource.kafka_data_disk, azurerm_linux_virtual_machine_scale_set.brokers]
}

###################### Multiple VMs with Public IPs #####################

# Create public IPs for each Kafka broker
resource "azurerm_public_ip" "kafka_brokers" {
  count               = var.kafka_instance_count
  name                = "kafka-prod-broker-ip-${count.index}"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Create network interfaces for each Kafka broker
resource "azurerm_network_interface" "kafka_brokers" {
  count               = var.kafka_instance_count
  name                = "kafka-prod-nic-${count.index}"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "kafka-prod-ip-config-${count.index}"
    subnet_id                     = azurerm_subnet.kafka.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.kafka_brokers[count.index].id
  }
}

# Associate NSG with each network interface
resource "azurerm_network_interface_security_group_association" "kafka_brokers" {
  count                     = var.kafka_instance_count
  network_interface_id      = azurerm_network_interface.kafka_brokers[count.index].id
  network_security_group_id = azurerm_network_security_group.example.id
}

# Create individual Kafka broker VMs
resource "azurerm_linux_virtual_machine" "kafka_brokers" {
  count               = var.kafka_instance_count
  name                = "kafka-prod-broker-${count.index}"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  size                = var.kafka_vm_size
  network_interface_ids = [
    azurerm_network_interface.kafka_brokers[count.index].id
  ]

  computer_name  = "kafka-broker-${count.index}"
  admin_username = var.kafka_admin_username

  admin_ssh_key {
    username   = var.kafka_admin_username
    public_key = file(pathexpand("~/.ssh/id_rsa.pub"))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "resf"
    offer     = "rockylinux-x86_64"
    sku       = "9-base"
    version   = "9.6.20250531"
  }

  plan {
    publisher = "resf"
    product   = "rockylinux-x86_64"
    name      = "9-base"
  }

  boot_diagnostics {
    storage_account_uri = null
  }
}

# Premium SSD v2 Data Disk
resource "azapi_resource" "kafka_data_disk" {
  count     = var.kafka_instance_count
  type      = "Microsoft.Compute/disks@2024-03-02"
  name      = "kafka-data-disk-${count.index}"
  location  = azurerm_resource_group.example.location
  parent_id = azurerm_resource_group.example.id

  body = {
    sku = {
      name = "PremiumV2_LRS"
    }
    properties = {
      diskSizeGB           = var.kafka_data_disk_size_gb
      diskIOPSReadWrite    = var.kafka_data_disk_iops
      diskMBpsReadWrite    = var.kafka_data_disk_throughput_mbps
      creationData = {
        createOption = "Empty"
      }
    }
  }
}

# Attach data disks
resource "azurerm_virtual_machine_data_disk_attachment" "kafka_data_disk" {
  count              = var.kafka_instance_count
  managed_disk_id    = azapi_resource.kafka_data_disk[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.kafka_brokers[count.index].id
  lun                = 0
  caching            = "None"

  depends_on = [azapi_resource.kafka_data_disk, azurerm_linux_virtual_machine.kafka_brokers]
}

# Output private and public IPs
output "kafka_private_ips" {
  description = "Private IP addresses assigned to Kafka brokers."
  value       = azurerm_linux_virtual_machine.kafka_brokers[*].private_ip_address
}

output "kafka_public_ips" {
  description = "Public IP addresses assigned to Kafka brokers."
  value       = azurerm_public_ip.kafka_brokers[*].ip_address
}

# Launch Ansible playbook
resource "null_resource" "launch_ansible_playbook" {
  triggers = {
    private_ips = join(",", azurerm_linux_virtual_machine.kafka_brokers[*].private_ip_address)
  }

  provisioner "local-exec" {
    working_dir = "../install_kafka_with_ansible_roles"
    command     = "mkdir -p generated && ./inventory_script_hosts_vms.sh ${azurerm_resource_group.example.name} ${var.kafka_admin_username} > generated/kafka_hosts && ansible-playbook -i generated/kafka_hosts deploy_kafka_playbook.yaml && ansible-playbook -i monitoring/generated_inventory.ini monitoring/deploy_monitoring_playbook.yml"
  }

  depends_on = [
    azurerm_virtual_machine_data_disk_attachment.kafka_data_disk,
    azurerm_linux_virtual_machine.kafka_brokers
  ]
}