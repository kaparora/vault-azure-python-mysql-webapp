data "azurerm_public_ip" "vault_ip" {
  name                = "${azurerm_public_ip.vault_ip.name}"
  resource_group_name = "${azurerm_virtual_machine.vault_vm.resource_group_name}"
}
data "azurerm_public_ip" "webapp_ip" {
  name                = "${azurerm_public_ip.webapp_ip.name}"
  resource_group_name = "${azurerm_virtual_machine.webapp.resource_group_name}"
}

output "webapp_ip" {
  value = "${data.azurerm_public_ip.webapp_ip.ip_address}"
}

output "vault_ip" {
  value = "${data.azurerm_public_ip.vault_ip.ip_address}"
}
output "vault_addr" {
  value = "http://${data.azurerm_public_ip.vault_ip.ip_address}:8200"
}


output "ssh-addr" {
  value = <<SSH

    Connect to your virtual machine via SSH:

    $ ssh azureuser@${data.azurerm_public_ip.vault_ip.ip_address}


SSH

}

output "webapp-url" {
  value = "http://${data.azurerm_public_ip.webapp_ip.ip_address}:5000"
}