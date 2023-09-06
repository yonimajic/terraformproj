# Output the public IP address of the Flask VM
output "flask_vm_public_ip" {
  value = azurerm_public_ip.flask.ip_address
}