resource "azurerm_managed_disk" "pv2" {
  for_each            = merge(local.vm_map, local.vm_map_subnet2)
  name                = "${each.key}-pv2-data"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  storage_account_type = "PremiumV2_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.pv2_data_disk.size_gb

  # PV2 性能参数
  disk_iops_read_write = var.pv2_data_disk.iops
  disk_mbps_read_write = var.pv2_data_disk.throughput_mbps
}

resource "azurerm_virtual_machine_data_disk_attachment" "pv2_attach" {
  for_each = merge(local.vm_map, local.vm_map_subnet2)

  managed_disk_id = azurerm_managed_disk.pv2[each.key].id
  virtual_machine_id = try(
    azurerm_linux_virtual_machine.vm[each.key].id,
    azurerm_linux_virtual_machine.vm_subnet2[each.key].id
  )

  lun     = var.pv2_data_disk.lun
  caching = var.pv2_data_disk.caching
}
