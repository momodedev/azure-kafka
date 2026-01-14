###################### Multiple VMs #####################

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
  # Deploy ALL VMs in Zone 1 to avoid capacity issues and disk alignment errors
  zone                = "2"
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
    sku       = "9-lvm"
    version   = "latest"
  }

  plan {
    publisher = "resf"
    product   = "rockylinux-x86_64"
    name      = "9-lvm"
  }

  identity {
    type = "SystemAssigned"
  }

  boot_diagnostics {
    storage_account_uri = null
  }
}

# Premium SSD v2 Data Disk with zone assignment
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
    # All disks in Zone 1 to match VMs
    zones = ["2"]
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

# Attach Premium SSD v2 disk to each VM
resource "azurerm_virtual_machine_data_disk_attachment" "kafka_data_disk" {
  count              = var.kafka_instance_count
  managed_disk_id    = azapi_resource.kafka_data_disk[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.kafka_brokers[count.index].id
  lun                = 0
  caching            = "None"

  depends_on = [azapi_resource.kafka_data_disk, azurerm_linux_virtual_machine.kafka_brokers]
}

# Output private IPs
output "kafka_private_ips" {
  description = "Private IP addresses assigned to Kafka brokers."
  value       = azurerm_linux_virtual_machine.kafka_brokers[*].private_ip_address
}

# Launch Ansible playbook after all VMs are ready
resource "null_resource" "launch_ansible_playbook" {
  triggers = {
    private_ips = join(",", azurerm_linux_virtual_machine.kafka_brokers[*].private_ip_address)
  }

  provisioner "local-exec" {
    working_dir = "../install_kafka_with_ansible_roles"
    command     = "az login --identity >/dev/null && mkdir -p generated && ./inventory_script_hosts_vms.sh ${azurerm_resource_group.example.name} ${var.kafka_admin_username} > generated/kafka_hosts && ansible-playbook -i generated/kafka_hosts deploy_kafka_playbook.yaml && ansible-playbook -i monitoring/generated_inventory.ini monitoring/deploy_monitoring_playbook.yml"
  }

  depends_on = [
    azurerm_virtual_machine_data_disk_attachment.kafka_data_disk,
    azurerm_linux_virtual_machine.kafka_brokers
  ]
}