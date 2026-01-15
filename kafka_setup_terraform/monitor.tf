resource "azurerm_public_ip" "monitor" {
  name                = "kafka-prod-monitor-ip"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "monitor" {
  name                = "kafka-prod-monitor-nsg"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  security_rule {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "prometheus"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9090"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "grafana"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "monitor" {
  name                = "kafka-prod-monitor-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "kafka-prod-monitor-ip-config"
    subnet_id                     = azurerm_subnet.kafka.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.monitor.id
  }
}

resource "azurerm_network_interface_security_group_association" "monitor" {
  network_interface_id      = azurerm_network_interface.monitor.id
  network_security_group_id = azurerm_network_security_group.monitor.id
}

resource "azurerm_linux_virtual_machine" "monitor" {
  name                = var.monitor_vm_name
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = var.monitor_vm_size
  network_interface_ids = [azurerm_network_interface.monitor.id]

  computer_name  = "kafka-prom"
  admin_username = var.monitor_admin_username

  admin_ssh_key {
    username   = var.monitor_admin_username
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
}

resource "null_resource" "deploy_monitoring" {
  triggers = {
    monitor_ip = azurerm_linux_virtual_machine.monitor.public_ip_address
    broker_ips = join(",", data.azurerm_virtual_machine_scale_set.brokers.instances.*.private_ip_address)
  }

  provisioner "local-exec" {
    working_dir = "../install_kafka_with_ansible_roles"
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i '${azurerm_linux_virtual_machine.monitor.public_ip_address},' -u ${var.monitor_admin_username} --ssh-extra-args='-o StrictHostKeyChecking=no' deploy_monitoring_playbook.yaml --extra-vars \"broker_ips=${join(",", data.azurerm_virtual_machine_scale_set.brokers.instances.*.private_ip_address)}\""
  }

  depends_on = [azurerm_linux_virtual_machine.monitor, azurerm_linux_virtual_machine_scale_set.brokers]
}

output "monitor_public_ip" {
  description = "Public IP address of the Prometheus/Grafana VM."
  value       = azurerm_public_ip.monitor.ip_address
}
