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

  data_disk {
    lun                  = 0
    caching              = "None"
    create_option        = "Empty"
    disk_size_gb         = var.kafka_data_disk_size_gb
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
    command      = "az login --identity >/dev/null && mkdir -p generated && ./inventory_script_hosts.sh ${azurerm_resource_group.example.name} ${azurerm_linux_virtual_machine_scale_set.brokers.name} ${var.kafka_admin_username} > generated/kafka_hosts && ansible-playbook -i generated/kafka_hosts deploy_kafka_playbook.yaml && ansible-playbook -i monitoring/generated_inventory.ini monitoring/deploy_monitoring_playbook.yml"
  }
}