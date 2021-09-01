resource "azurerm_public_ip" "vault_ip" {
  name                = "${var.prefix}-vault-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"

  tags = {
    owner = var.owner
  }
}