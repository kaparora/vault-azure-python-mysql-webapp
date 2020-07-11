resource "azurerm_storage_account" "storageaccount" {
  name                     = "sa${random_id.sa.hex}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    owner = "${var.owner}"
  }
}

resource "random_id" "sa" {
  byte_length = 6
}