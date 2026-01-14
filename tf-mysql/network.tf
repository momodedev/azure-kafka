
resource "azurerm_virtual_network" "vnet" {
  name                = "${local.name_prefix_effective}-vnet"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "time_sleep" "after_vnet" {
  create_duration = "30s"
  depends_on      = [azurerm_virtual_network.vnet]
}

resource "azurerm_subnet" "subnet" {
  name                 = "${local.name_prefix_effective}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_cidr]

  depends_on = [time_sleep.after_vnet]
}

resource "azurerm_subnet" "subnet2" {
  count                = var.enable_second_subnet ? 1 : 0
  name                 = "${local.name_prefix_effective}-subnet2"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet2_cidr]

  depends_on = [time_sleep.after_vnet]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "${local.name_prefix_effective}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "time_sleep" "after_nsg" {
  create_duration = "30s"
  depends_on      = [azurerm_network_security_group.nsg]
}

# 允许 VNet 内部访问指定端口（入站）

resource "azurerm_network_security_rule" "allow_internal_ports" {
  for_each = {
    for i, p in var.internal_tcp_ports : tostring(p) => i
  }

  name                        = "Allow-VNet-TCP-${each.key}"
  priority                    = 1000 + each.value # 1000,1001,1002... (合法 100-4096)
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = each.key # 端口号
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name

  depends_on = [time_sleep.after_nsg]
}

resource "azurerm_network_security_rule" "allow_ssh_from_ansible" {
  count = var.enable_ansible_ssh_whitelist ? 1 : 0

  name                        = "Allow-SSH-From-Ansible"
  priority                    = 900
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = var.ansible_server_private_ip
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name

  depends_on = [time_sleep.after_nsg]
}


resource "azurerm_subnet_network_security_group_association" "subnet_assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id

  depends_on = [time_sleep.after_nsg, time_sleep.after_vnet]
}

resource "azurerm_subnet_network_security_group_association" "subnet2_assoc" {
  count                     = var.enable_second_subnet ? 1 : 0
  subnet_id                 = azurerm_subnet.subnet2[0].id
  network_security_group_id = azurerm_network_security_group.nsg.id

  depends_on = [time_sleep.after_nsg, time_sleep.after_vnet]
}

data "azurerm_virtual_network" "jumpserver_vnet" {
  count               = var.enable_jumpserver_vnet_peering ? 1 : 0
  name                = var.jumpserver_vnet_name
  resource_group_name = var.jumpserver_vnet_resource_group_name
}

resource "azurerm_virtual_network_peering" "local_to_jumpserver" {
  count = var.enable_jumpserver_vnet_peering ? 1 : 0

  name                      = "${local.name_prefix_effective}-to-jumpserver"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet.name
  remote_virtual_network_id = data.azurerm_virtual_network.jumpserver_vnet[0].id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "jumpserver_to_local" {
  count = var.enable_jumpserver_vnet_peering ? 1 : 0

  name                      = "jumpserver-to-${local.name_prefix_effective}"
  resource_group_name       = var.jumpserver_vnet_resource_group_name
  virtual_network_name      = var.jumpserver_vnet_name
  remote_virtual_network_id = azurerm_virtual_network.vnet.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}
