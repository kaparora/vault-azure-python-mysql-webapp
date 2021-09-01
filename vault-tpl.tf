data "template_file" "vault_setup" {
  template = file("${path.module}/setup-vault.tpl")

  vars = {
    resource_group_name = "${var.prefix}-rg"
    vault_vm_name       = "${var.prefix}-vault-vm"
    webapp_vm_name      = "${var.prefix}-webapp-vm"
    vault_download_url  = var.vault_download_url
    tenant_id           = var.tenant_id
    subscription_id     = var.subscription_id
    client_id           = var.client_id
    client_secret       = var.client_secret
    vault_name          = azurerm_key_vault.keyvault.name
    key_name            = azurerm_key_vault_key.generated.name
    mysql_endpoint      = "${azurerm_mysql_server.mysql.fqdn}:3306"
    mysql_username      = "${var.mysql_username}@${azurerm_mysql_server.mysql.name}"
    mysql_password      = var.mysql_password
    license             = var.license
    vault_namespace     = var.vault_namespace
  }
}