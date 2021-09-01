resource "azurerm_network_security_group" "webapp_nsg" {
  name                = "${var.prefix}-webapp-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Webapp"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "MySQL"
    priority                   = 1003
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    owner = var.owner
  }
}

resource "azurerm_network_interface" "webapp_nic" {
  name                      = "${var.prefix}-webapp-nic"
  location                  = var.location
  resource_group_name       = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "${var.prefix}-webapp-nic"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = azurerm_public_ip.webapp_ip.id
}

  tags = {
    owner = var.owner
  }
}

resource "azurerm_network_interface_security_group_association" "webapp_nic_nsg" {
  network_interface_id      = azurerm_network_interface.webapp_nic.id
  network_security_group_id = azurerm_network_security_group.webapp_nsg.id
}