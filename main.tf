resource "azurerm_resource_group" "production" {
  name     = "terraform-azure"
  location = "West US"

}

resource "azurerm_virtual_machine" "my-tf-instance" {
  name                  = "my-tf-vm"
  resource_group_name   = azurerm_resource_group.production.name
  location              = azurerm_resource_group.production.location
  vm_size               = "Standard_B1S"
  network_interface_ids = [azurerm_network_interface.my-tf-nic.id]

  storage_os_disk {
    name              = "myOsDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = var.azure_computer_name
    admin_username = var.azure_linux_user_name
    admin_password = var.azure_linux_user_password
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = var.azure_ssh_user_path
      key_data = var.azure_ssh_pub_key
    }
  }

  tags = {
    environment = "TF-demo"
  }
}

resource "azurerm_virtual_network" "my-tf-network" {
  name                = "my-tf-vnet"
  address_space       = ["10.0.0.0/16"]
  resource_group_name = azurerm_resource_group.production.name
  location            = azurerm_resource_group.production.location

  tags = {
    environment = "TF-demo"
  }
}

resource "azurerm_subnet" "my-tf-subnet" {
  name                 = "my-tf-subnet"
  resource_group_name  = azurerm_resource_group.production.name
  virtual_network_name = azurerm_virtual_network.my-tf-network.name
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_network_interface" "my-tf-nic" {
  name                      = "my-tf-nic"
  location                  = azurerm_resource_group.production.location
  resource_group_name       = azurerm_resource_group.production.name
  network_security_group_id = azurerm_network_security_group.my-tf-sec-group.id

  ip_configuration {
    name                          = "my-tf-nic-config"
    subnet_id                     = azurerm_subnet.my-tf-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.my-tf-public-ip.id
  }

  tags = {
    environment = "TF-demo"
  }
}

resource "azurerm_public_ip" "my-tf-public-ip" {
  name                = "my-tf-public-ip"
  location            = azurerm_resource_group.production.location
  resource_group_name = azurerm_resource_group.production.name
  allocation_method   = "Dynamic"

  tags = {
    environment = "TF-Demo"
  }
}

data "azurerm_public_ip" "example" {
  name                = azurerm_public_ip.my-tf-public-ip.name
  resource_group_name = azurerm_virtual_machine.my-tf-instance.resource_group_name
}

output "public_ip_address" {
  value = data.azurerm_public_ip.example.ip_address
}

resource "azurerm_network_security_group" "my-tf-sec-group" {
  name                = "my-tf-sec-group"
  location            = azurerm_resource_group.production.location
  resource_group_name = azurerm_resource_group.production.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = 22
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
