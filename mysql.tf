resource "azurerm_mysql_server" "mysql" {
  name                = "${var.prefix}-mysqlserver"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  administrator_login          = var.mysql_username
  administrator_login_password = var.mysql_password

  sku_name   = "GP_Gen5_2"
  storage_mb = 5120
  version    = "5.7"

  auto_grow_enabled                 = false
  backup_retention_days             = 7
  geo_redundant_backup_enabled      = false
  infrastructure_encryption_enabled = false
  public_network_access_enabled     = true
  ssl_enforcement_enabled           = false
}

resource "azurerm_mysql_virtual_network_rule" "mysql_vnet_rule" {
  name                = "mysql-vnet-rule"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_server.mysql.name
  subnet_id           = azurerm_subnet.subnet.id
}