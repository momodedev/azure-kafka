############### RG #################
data azurerm_subscription "current" { }
data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "example" {
  location = var.resource_group_location
  name     = var.resource_group_name
}

resource "azurerm_virtual_network" "control" {
  name                = "control-vnet"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  address_space = ["172.17.0.0/16"]
}

resource "azurerm_subnet" "control" {
  name                 = "control-subnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.control.name
  address_prefixes     = ["172.17.1.0/24"]
  service_endpoints    = ["Microsoft.KeyVault"]
  default_outbound_access_enabled = false
}

resource "azurerm_network_security_group" "example" {
  name                = "control-nsg"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  security_rule {
    name                       = "test123"
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

resource "azurerm_subnet_network_security_group_association" "example" {
  subnet_id                 = azurerm_subnet.control.id
  network_security_group_id = azurerm_network_security_group.example.id
}

resource "azurerm_public_ip" "control" {
  name                = "control-ip"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "example" {
  name                = "control-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.control.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.control.id
  }
}

resource "azurerm_linux_virtual_machine" "example" {
  name                = "control-node"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = "Standard_D4as_v5"
  network_interface_ids = [
    azurerm_network_interface.example.id,
  ]

  computer_name  = "control"
  admin_username = "azureadmin"
  admin_ssh_key {
    username   = "azureadmin"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  connection {
    type = "ssh"
    user = "azureadmin"
    host = self.public_ip_address
    private_key = file("~/.ssh/id_rsa")
  }
  provisioner "file" {
    source      = "private_vmss_init.sh"
    destination = "private_vmss_init.sh"
  }
  provisioner "file" {
    source      = "private_vmss_deploy.sh"
    destination = "private_vmss_deploy.sh"
  }
  # provisioner "remote-exec" {
  #   when    = destroy
  #   inline = [
  #     "cd azure-kafka/kafka_setup_terraform_private_vmss",
  #     "terraform destroy -var-file='sub_id.tfvars' -auto-approve",
  #   ]
  # }
}


resource "azurerm_role_assignment" "control" {
  scope              = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id       = azurerm_linux_virtual_machine.example.identity[0].principal_id
}


resource "azurerm_role_assignment" "user" {
  scope              = azurerm_key_vault.example.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id       = data.azurerm_client_config.current.object_id
}


resource "null_resource" "deploy_private_vmss"{
  triggers = { 
    always_run = "${timestamp()}"
  }
  connection {
    type = "ssh"
    host = azurerm_linux_virtual_machine.example.public_ip_address
    user = "azureadmin"
    private_key = file("~/.ssh/id_rsa")
  }
  provisioner "remote-exec" {
    inline = [
      "./private_vmss_deploy.sh ${var.ARM_SUBSCRIPTION_ID} ${var.tf_cmd_type} ${var.kafka_instance_count} ${var.kafka_data_disk_iops} ${var.kafka_data_disk_throughput_mbps} ${var.kafka_vm_size}",
    ]
  }
  depends_on = [null_resource.Init_private_vmss]
}


resource "null_resource" "Init_private_vmss"{
  triggers = { 
    trigger = join(",", azurerm_linux_virtual_machine.example.public_ip_addresses) 
  }
  connection {
    type = "ssh"
    host = azurerm_linux_virtual_machine.example.public_ip_address
    user = "azureadmin"
    private_key = file("~/.ssh/id_rsa")
  }
  provisioner "remote-exec" {
    inline = [
      "chmod +x private_vmss_init.sh",
      "chmod +x private_vmss_deploy.sh",
      "./private_vmss_init.sh",
    ]
  }
  depends_on = [azurerm_role_assignment.control, azurerm_role_assignment.keyvault, azurerm_key_vault_secret.example, azurerm_linux_virtual_machine.example]
}



# resource "azurerm_virtual_machine_extension" "example" {
#   name                 = "hostname"
#   virtual_machine_id   = azurerm_linux_virtual_machine.example.id
#   publisher            = "Microsoft.Azure.Extensions"
#   type                 = "CustomScript"
#   type_handler_version = "2.0"

#   protected_settings = <<PROT
#   {
#       "script": "${base64encode(templatefile("private_vmss_init.sh", { sub_id=var.ARM_SUBSCRIPTION_ID }))}"
#   }
#   PROT

#   depends_on = [azurerm_role_assignment.control, azurerm_role_assignment.keyvault, azurerm_key_vault_secret.example]
# }