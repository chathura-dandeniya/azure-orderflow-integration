# Separate account for business data (orders), kept apart from the Function's internal storage
resource "azurerm_storage_account" "data" {
  name                     = "st${var.project}${var.environment}data${random_string.suffix.result}"
  location                 = azurerm_resource_group.main.location
  resource_group_name      = azurerm_resource_group.main.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = var.tags
}

resource "azurerm_storage_table" "orders" {
  name               = "orders"
  storage_account_id = azurerm_storage_account.data.id
}