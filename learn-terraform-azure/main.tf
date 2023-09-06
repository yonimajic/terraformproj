variable "db_username" {}
variable "db_password" {}
variable "flask_username" {}
variable "flask_password" {}


resource "tls_private_key" "example_ssh" {
    algorithm = "RSA"
    rsa_bits = 4096
}

resource "azurerm_resource_group" "example" {
  name = "terraform-demo-rg"
  location = "West Europe"
}

resource "azurerm_virtual_network" "terraform_demo" {
  name = "terraform-demo-vnet"
  resource_group_name = azurerm_resource_group.example.name
  location = azurerm_resource_group.example.location
  address_space = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "web_subnet" {
  name = "web-subnet"
  resource_group_name = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.terraform_demo.name
  address_prefixes = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "db_subnet" {
  name = "db-subnet"
  resource_group_name = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.terraform_demo.name
  address_prefixes = ["10.0.2.0/24"]
}

resource "azurerm_availability_set" "example" {
  name                = "my-availability-set"
  resource_group_name = azurerm_resource_group.example.name
  location = azurerm_resource_group.example.location
}

# Create an Azure public IP address for the Flask VM
resource "azurerm_public_ip" "flask" {
  name                = "flask-ip"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  allocation_method   = "Dynamic"
}

resource "azurerm_public_ip" "postgresql" {
  name                = "postgresql-ip"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  allocation_method   = "Dynamic"
}
# Create the Flask VM
resource "azurerm_linux_virtual_machine" "flask" {
  name                = "flask-vm"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = "Standard_B1s"
  admin_username      = var.flask_username
  admin_password      = var.flask_password  
  network_interface_ids = [
    azurerm_network_interface.flask.id,
  ]
  availability_set_id = azurerm_availability_set.example.id
  
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  computer_name  = "hostname"
  
  disable_password_authentication = true

    admin_ssh_key {
        username = var.flask_username
        public_key = file("C:\\Users\\Liel\\.ssh\\id_rsa.pub")
        #tls_private_key.example_ssh.public_key_openssh 
    }

     provisioner "file" {
    source      = "C:/learn-terraform-azure/flask_script.sh"
    destination = "/tmp/flask_script.sh"
  
  connection {
    type     = "ssh"
    user     = var.flask_username
    password = var.flask_password
    host     = azurerm_linux_virtual_machine.flask.public_ip_address
    private_key = file("C:\\Users\\Liel\\.ssh\\id_rsa")
  
  }
     }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/flask_script.sh",
      "/tmp/flask_script.sh",
    ]

    connection {
    type     = "ssh"
    user     = var.flask_username
    password = var.flask_password
    host     = azurerm_linux_virtual_machine.flask.public_ip_address
    private_key = file("C:\\Users\\Liel\\.ssh\\id_rsa")
  
  }
  }
}



resource "azurerm_managed_disk" "flask-md" {
  name                 = "flask-md"
  location             = azurerm_resource_group.example.location
  resource_group_name  = azurerm_resource_group.example.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 10
}


resource "azurerm_virtual_machine_data_disk_attachment" "flask-attach" {
  managed_disk_id    = azurerm_managed_disk.flask-md.id
  virtual_machine_id = azurerm_linux_virtual_machine.flask.id
  lun                ="10"
  caching            = "ReadWrite"
}
# Create a network interface for the Flask VM
resource "azurerm_network_interface" "flask" {
  name                = "flask-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "flask-ip-config"
    subnet_id                     = azurerm_subnet.web_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id           = azurerm_public_ip.flask.id
  }
}


resource "azurerm_network_interface" "postgresql" {
  name                = "postgresql-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "postgresql-ip-config"
    subnet_id                     = azurerm_subnet.db_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id           = azurerm_public_ip.postgresql.id
  }

  depends_on = [azurerm_subnet.db_subnet]
}

# Create the PostgreSQL VM
resource "azurerm_linux_virtual_machine" "postgresql" {
  name                = "postgresql-vm"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = "Standard_B1s"
  
  network_interface_ids = [
    azurerm_network_interface.postgresql.id,
  ]
  availability_set_id = azurerm_availability_set.example.id  
 
  disable_password_authentication = true

  admin_ssh_key {
        username = var.db_username
        public_key = file("C:\\Users\\Liel\\.ssh\\id_rsa.pub")
        #tls_private_key.example_ssh.public_key_openssh 
    }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  
 
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

   computer_name  = "hostname"
   admin_username      = var.db_username
   admin_password      = var.db_password 
  
        provisioner "file" {
    source      = "C:/learn-terraform-azure/psql_script.sh"
    destination = "/tmp/psql_script.sh"
  
   connection {
    type     = "ssh"
    user     = var.db_username
    password = var.db_password
    host     = azurerm_linux_virtual_machine.postgresql.public_ip_address
    private_key = file("C:\\Users\\Liel\\.ssh\\id_rsa")
  }
  
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/psql_script.sh",
      "/tmp/psql_script.sh",
    ]

    connection {
    type     = "ssh"
    user     = var.db_username
    password = var.db_password
    host     = azurerm_linux_virtual_machine.postgresql.public_ip_address
    private_key = file("C:\\Users\\Liel\\.ssh\\id_rsa")
  }
  }
 
  
 
}

 resource "azurerm_managed_disk" "psql-md" {
  name                 = "psql-md"
  location             = azurerm_resource_group.example.location
  resource_group_name  = azurerm_resource_group.example.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 10
}


resource "azurerm_virtual_machine_data_disk_attachment" "psql-attach" {
  managed_disk_id    = azurerm_managed_disk.psql-md.id
  virtual_machine_id = azurerm_linux_virtual_machine.postgresql.id
  lun                ="10"
  caching            = "ReadWrite"
}

resource "azurerm_network_security_group" "web_nsg" {
  name = "web-nsg"
  resource_group_name = azurerm_resource_group.example.name
  location = azurerm_resource_group.example.location


  security_rule {
    name = "AllowHTTP"
    priority = 100
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "8080"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }


  security_rule {
    name = "AllowSSH"
    priority = 110
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "22"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "db_nsg" {
  name = "db-nsg"
  resource_group_name = azurerm_resource_group.example.name
  location = azurerm_resource_group.example.location


  security_rule {
    name = "AllowAPPAccess"
    priority = 100
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "5432"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }


  security_rule {
    name = "AllowSSH"
    priority = 110
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "22"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }  
}

