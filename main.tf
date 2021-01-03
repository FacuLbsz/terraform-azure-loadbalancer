# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.26"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "terraformAzureLoadbalancerRg"
  location = "eastus"
}

resource "azurerm_virtual_network" "vn" {
  name                = "terraformAzureLoadbalancerVn"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_container_registry" "cr" {
  name                     = "terraformAzureLoadbalancerAcr"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  sku                      = "Basic"
  admin_enabled            = true
}

resource "azurerm_subnet" "sn" {
  name                 = "terraformAzureLoadbalancerSb"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vn.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "p1" {
  name                = "terraformAzureLoadbalancerPi1"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Dynamic"
}

resource "azurerm_public_ip" "p2" {
  name                = "terraformAzureLoadbalancerPi2"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Dynamic"
}


resource "azurerm_network_security_group" "nsg" {
  name                = "terraformAzureLoadbalancerNsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    access = "Allow"
    direction = "Inbound"
    name = "SSH"
    priority = 300
    protocol = "TCP"
    source_port_range = "*"
    destination_port_range = "22"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    access = "Allow"
    direction = "Inbound"
    name = "HTTP-8080"
    priority = 301
    protocol = "TCP"
    source_port_range = "*"
    destination_port_range = "8080"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "ni1" {
  name                = "terraformAzureLoadbalancerNi1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.sn.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.p1.id
  }
}

resource "azurerm_network_interface" "ni2" {
  name                = "terraformAzureLoadbalancerNi2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.sn.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.p2.id
  }
}

resource "azurerm_network_interface_security_group_association" "nisga1" {
  network_interface_id      = azurerm_network_interface.ni1.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_network_interface_security_group_association" "nisga2" {
  network_interface_id      = azurerm_network_interface.ni2.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_availability_set" "as" {
  name                = "terraformAzureLoadbalancerAs"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  platform_fault_domain_count = 2
  platform_update_domain_count = 2
}

resource "azurerm_linux_virtual_machine" "vm1" {
  name                = "terraformAzureLoadbalancerVm1"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  availability_set_id = azurerm_availability_set.as.id
  size                = "Standard_B1ms"
  disable_password_authentication = false
  admin_username      = "adminuser"
  admin_password = "1234@Adminuser"
  network_interface_ids = [
    azurerm_network_interface.ni1.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "vm2" {
  name                = "terraformAzureLoadbalancerVm2"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  availability_set_id = azurerm_availability_set.as.id
  size                = "Standard_B1ms"
  disable_password_authentication = false
  admin_username      = "adminuser"
  admin_password = "1234@Adminuser"
  network_interface_ids = [
    azurerm_network_interface.ni2.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}

resource "azurerm_public_ip" "pilb" {
  name                = "terraformAzureLoadbalancerPilb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

variable "lb_frontend_ip_configuration_name" {
  type = string
  default = "primary"
}

resource "azurerm_lb" "lb" {
  name                = "terraformAzureLoadbalancerLb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  frontend_ip_configuration {
    name                 = var.lb_frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.pilb.id
  }
}

resource "azurerm_lb_backend_address_pool" "lbbadp" {
  name                = "terraformAzureLoadbalancerLbbadp"
  resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id     = azurerm_lb.lb.id
}

resource "azurerm_network_interface_backend_address_pool_association" "nibapa1" {
  ip_configuration_name   = "internal"
  network_interface_id    = azurerm_network_interface.ni1.id
  backend_address_pool_id = azurerm_lb_backend_address_pool.lbbadp.id
}

resource "azurerm_network_interface_backend_address_pool_association" "nibapa2" {
  ip_configuration_name   = "internal"
  network_interface_id    = azurerm_network_interface.ni2.id
  backend_address_pool_id = azurerm_lb_backend_address_pool.lbbadp.id
}

resource "azurerm_lb_probe" "lbp" {
  resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id     = azurerm_lb.lb.id
  name                = "terraformAzureLoadbalancerLbp"
  port                = 8080
  protocol = "Http"
  request_path = "/"
  interval_in_seconds = 5
}

resource "azurerm_lb_rule" "lbr" {
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "terraformAzureLoadbalancerLbr"
  protocol                       = "Tcp"
  frontend_port                  = 8080
  backend_port                   = 8080
  frontend_ip_configuration_name = var.lb_frontend_ip_configuration_name
  backend_address_pool_id = azurerm_lb_backend_address_pool.lbbadp.id
  probe_id = azurerm_lb_probe.lbp.id
}

output "vm1" {
  value = azurerm_linux_virtual_machine.vm1.public_ip_address
}

output "vm2" {
  value = azurerm_linux_virtual_machine.vm2.public_ip_address
}