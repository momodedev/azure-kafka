###################### Multiple VMs #####################

# Create network interfaces for each Kafka broker (NO public IPs)
resource "azurerm_network_interface" "kafka_brokers" {
  count               = var.kafka_instance_count
  name                = "kafka-prod-nic-${count.index}"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "kafka-prod-ip-config-${count.index}"
    subnet_id                     = azurerm_subnet.kafka.id
    private_ip_address_allocation = "Dynamic"
    # REMOVED: public_ip_address_id - private cluster doesn't need public IPs
  }
}

# Associate NSG with each network interface
resource "azurerm_network_interface_security_group_association" "kafka_brokers" {
  count                     = var.kafka_instance_count
  network_interface_id      = azurerm_network_interface.kafka_brokers[count.index].id
  network_security_group_id = azurerm_network_security_group.example.id
}

# Create individual Kafka broker VMs in Zone 2 (private cluster)
resource "azurerm_linux_virtual_machine" "kafka_brokers" {
  count               = var.kafka_instance_count
  name                = "kafka-prod-broker-${count.index}"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  size                = var.kafka_vm_size
  zone                = "2"  # Deploy in Zone 2
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

  identity {
    type = "SystemAssigned"
  }

  boot_diagnostics {
    storage_account_uri = null
  }
}

# PremiumV2_LRS Data Disks
resource "azurerm_managed_disk" "kafka_data_disk" {
  count               = var.kafka_instance_count
  name                = "kafka-data-disk-${count.index}"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  storage_account_type = "PremiumV2_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.kafka_data_disk_size_gb
  zone                 = "2"  # Must match VM zone

  # PremiumV2 performance parameters
  disk_iops_read_write    = var.kafka_data_disk_iops
  disk_mbps_read_write    = var.kafka_data_disk_throughput_mbps
}

# Attach data disks to each VM
resource "azurerm_virtual_machine_data_disk_attachment" "kafka_data_disk" {
  count              = var.kafka_instance_count
  managed_disk_id    = azurerm_managed_disk.kafka_data_disk[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.kafka_brokers[count.index].id
  lun                = 0
  caching            = "None"
}

# Output private IPs only (no public IPs for private cluster)
output "kafka_private_ips" {
  description = "Private IP addresses assigned to Kafka brokers."
  value       = azurerm_linux_virtual_machine.kafka_brokers[*].private_ip_address
}

# Launch Ansible playbook after all VMs are ready
resource "null_resource" "launch_ansible_playbook" {
  triggers = {
    kafka_count = var.kafka_instance_count
    private_ips = join(",", sort(azurerm_linux_virtual_machine.kafka_brokers[*].private_ip_address))
  }

  provisioner "local-exec" {
    working_dir = "/home/azureadmin/azure-kafka/install_kafka_with_ansible_roles"
    interpreter = ["/bin/bash", "-c"]
    command     = "source /home/azureadmin/ansible-venv/bin/activate && az login --identity >/dev/null && mkdir -p generated && bash ./inventory_script_hosts_vms.sh ${azurerm_resource_group.example.name} ${var.kafka_admin_username} > generated/kafka_hosts && ansible-playbook -i generated/kafka_hosts deploy_kafka_playbook.yaml && ansible-playbook -i monitoring/generated_inventory.ini monitoring/deploy_monitoring_playbook.yml"
  }

  depends_on = [
    azurerm_virtual_machine_data_disk_attachment.kafka_data_disk,
    azurerm_linux_virtual_machine.kafka_brokers
  ]
}