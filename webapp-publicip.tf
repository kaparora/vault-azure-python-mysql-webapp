resource "azurerm_public_ip" "webapp_ip" {
  name                = "${var.prefix}-webapp-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"

  tags = {
    owner = var.owner
  }
}