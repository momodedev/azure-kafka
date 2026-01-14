resource "tls_private_key" "ansible_controller" {
  count     = var.enable_auto_ansible_ssh_key ? 1 : 0
  algorithm = "ED25519"
}

locals {
  auto_ansible_controller_public_key = var.enable_auto_ansible_ssh_key ? tls_private_key.ansible_controller[0].public_key_openssh : null

  # Base64 so we can safely embed it into cloud-init and decode on the VM.
  auto_ansible_controller_private_key_b64 = var.enable_auto_ansible_ssh_key ? base64encode(tls_private_key.ansible_controller[0].private_key_openssh) : ""

  extra_ssh_public_keys_effective = (
    var.enable_auto_ansible_ssh_key
    ? concat(var.extra_ssh_public_keys, [local.auto_ansible_controller_public_key])
    : var.extra_ssh_public_keys
  )
}
