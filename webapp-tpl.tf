
data "template_file" "webapp_setup" {
  template = file("${path.module}/setup-webapp.tpl")

  vars = {
    resource_group_name = "${var.prefix}-rg"
    vault_download_url  = var.vault_download_url
    mysql_addr          = azurerm_mysql_server.mysql.fqdn
    vault_addr          = "http://${data.azurerm_public_ip.vault_ip.ip_address}:8200"
    mysql_name          = azurerm_mysql_server.mysql.name
    vault_namespace     = var.vault_namespace
  }
}