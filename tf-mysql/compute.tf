resource "azurerm_network_interface" "nic" {
  for_each            = local.vm_map
  name                = "${each.key}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "nic_subnet2" {
  for_each            = local.vm_map_subnet2
  name                = "${each.key}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet2[0].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  for_each             = local.vm_map
  name                 = each.key
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  size                 = var.vm_size
  disk_controller_type = "NVMe"

  admin_username                  = var.admin_username
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.nic[each.key].id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  dynamic "admin_ssh_key" {
    for_each = local.extra_ssh_public_keys_effective
    content {
      username   = var.admin_username
      public_key = admin_ssh_key.value
    }
  }

  os_disk {
    name                 = "${each.key}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }

  # Rocky Linux 9.6 LVM (x86_64) - Official from Rocky Enterprise Software Foundation (resf)
  # Supports both SCSI and NVMe disk controllers
  # URN: resf:rockylinux-x86_64:9-lvm:9.6.20250531
  source_image_reference {
    publisher = "resf"
    offer     = "rockylinux-x86_64"
    sku       = "9-lvm"
    version   = "9.6.20250531"
  }

  plan {
    name      = "9-lvm"
    product   = "rockylinux-x86_64"
    publisher = "resf"
  }
}

resource "azurerm_linux_virtual_machine" "vm_subnet2" {
  for_each             = local.vm_map_subnet2
  name                 = each.key
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  size                 = coalesce(var.vm_size_subnet2, var.vm_size)
  disk_controller_type = "NVMe"

  admin_username                  = var.admin_username
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.nic_subnet2[each.key].id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  dynamic "admin_ssh_key" {
    for_each = local.extra_ssh_public_keys_effective
    content {
      username   = var.admin_username
      public_key = admin_ssh_key.value
    }
  }

  os_disk {
    name                 = "${each.key}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = "resf"
    offer     = "rockylinux-x86_64"
    sku       = "9-lvm"
    version   = "9.6.20250531"
  }

  plan {
    name      = "9-lvm"
    product   = "rockylinux-x86_64"
    publisher = "resf"
  }
}

resource "azurerm_network_interface" "ansible_controller_nic" {
  count               = var.enable_ansible_controller_vm ? 1 : 0
  name                = "${var.ansible_controller_vm_name}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}



resource "azurerm_linux_virtual_machine" "ansible_controller" {
  count                = var.enable_ansible_controller_vm ? 1 : 0
  name                 = var.ansible_controller_vm_name
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  size                 = var.ansible_controller_vm_size
  disk_controller_type = "NVMe"

  admin_username                  = var.admin_username
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.ansible_controller_nic[0].id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  dynamic "admin_ssh_key" {
    for_each = local.extra_ssh_public_keys_effective
    content {
      username   = var.admin_username
      public_key = admin_ssh_key.value
    }
  }

  os_disk {
    name                 = "${var.ansible_controller_vm_name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = "resf"
    offer     = "rockylinux-x86_64"
    sku       = "9-lvm"
    version   = "9.6.20250531"
  }

  plan {
    name      = "9-lvm"
    product   = "rockylinux-x86_64"
    publisher = "resf"
  }

  custom_data = base64encode(<<-EOF
    #cloud-config
    runcmd:
      - |
        set -euo pipefail
        mkdir -p /data
        # Minimal bootstrap for an Ansible controller
        dnf -y install epel-release || true
        dnf -y install ansible-core git python3 python3-pip || true
        
        # Install required Ansible collections globally with sleep to avoid lock issues
        sleep 10
        mkdir -p /usr/share/ansible/collections
        ansible-galaxy collection install community.mysql community.general ansible.posix -p /usr/share/ansible/collections || true

        ansible --version || true

        # If enabled, write Terraform-generated SSH private key for controller -> MySQL
        if [ "${var.enable_auto_ansible_ssh_key}" = "true" ]; then
          install -d -m 0700 -o ${var.admin_username} -g ${var.admin_username} /home/${var.admin_username}/.ssh
          echo "${local.auto_ansible_controller_private_key_b64}" | base64 -d > /home/${var.admin_username}/.ssh/id_ed25519
          chown ${var.admin_username}:${var.admin_username} /home/${var.admin_username}/.ssh/id_ed25519
          chmod 0600 /home/${var.admin_username}/.ssh/id_ed25519
          ssh-keygen -y -f /home/${var.admin_username}/.ssh/id_ed25519 > /home/${var.admin_username}/.ssh/id_ed25519.pub || true
          chown ${var.admin_username}:${var.admin_username} /home/${var.admin_username}/.ssh/id_ed25519.pub || true
          chmod 0644 /home/${var.admin_username}/.ssh/id_ed25519.pub || true
        fi
    EOF
  )
}
