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
  single_placement_group = true

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

  admin_username = var.kafka_admin_username

  admin_ssh_key {
    username   = var.kafka_admin_username
    public_key = file(pathexpand("~/.ssh/id_rsa.pub"))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  # Premium SSD v2 data disks are attached separately via azapi_resource
  # due to Terraform/AzureRM provider limitations for IOPS/throughput configuration

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

# Premium SSD v2 Data Disk with configurable IOPS/Throughput
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

# Attach Premium SSD v2 disk to each VMSS instance using attachDetachDataDisks action
resource "azapi_resource_action" "attach_data_disk" {
  count       = var.kafka_instance_count
  resource_id = "${azurerm_linux_virtual_machine_scale_set.brokers.id}/virtualMachines/${count.index}"
  type        = "Microsoft.Compute/virtualMachineScaleSets/virtualMachines@2025-04-01"
  action      = "attachDetachDataDisks"
  method      = "POST"

  body = jsonencode({
    dataDisksToAttach = [
      {
        diskId  = azapi_resource.kafka_data_disk[count.index].id
        lun     = 0
        caching = "None"
      }
    ]
    dataDisksToDetach = []
  })

  depends_on = [azapi_resource.kafka_data_disk, azurerm_linux_virtual_machine_scale_set.brokers]
}

data "azurerm_virtual_machine_scale_set" "brokers" {
  name                = azurerm_linux_virtual_machine_scale_set.brokers.name
  resource_group_name = azurerm_resource_group.example.name
  depends_on          = [azapi_resource_action.attach_data_disk]
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
    command      = "az login --identity >/dev/null && mkdir -p generated && ./inventory_script_hosts.sh ${azurerm_resource_group.example.name} ${azurerm_linux_virtual_machine_scale_set.brokers.name} ${var.kafka_admin_username} > generated/kafka_hosts && ansible-playbook -i generated/kafka_hosts deploy_kafka_playbook.yaml && ansible-playbook -i monitoring/generated_inventory.ini monitoring/deploy_monitoring_playbook.yml"
  }

  depends_on = [data.azurerm_virtual_machine_scale_set.brokers]
}

data "azurerm_virtual_machine_scale_set" "brokers" {
  name                = azurerm_linux_virtual_machine_scale_set.brokers.name
  resource_group_name = azurerm_resource_group.example.name
  depends_on          = [azapi_resource_action.attach_data_disk]
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
    command      = "az login --identity >/dev/null && mkdir -p generated && ./inventory_script_hosts.sh ${azurerm_resource_group.example.name} ${azurerm_linux_virtual_machine_scale_set.brokers.name} ${var.kafka_admin_username} > generated/kafka_hosts && ansible-playbook -i generated/kafka_hosts deploy_kafka_playbook.yaml && ansible-playbook -i monitoring/generated_inventory.ini monitoring/deploy_monitoring_playbook.yml"
  }

  depends_on = [data.azurerm_virtual_machine_scale_set.brokers]
}