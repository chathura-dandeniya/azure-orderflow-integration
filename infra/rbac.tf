# Function App -> can send messages to Service Bus
resource "azurerm_role_assignment" "func_sb_sender" {
  scope                = azurerm_servicebus_namespace.main.id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}

data "azurerm_client_config" "current" {}

# Developer (you) -> full data access for local testing
resource "azurerm_role_assignment" "dev_sb_owner" {
  scope                = azurerm_servicebus_namespace.main.id
  role_definition_name = "Azure Service Bus Data Owner"
  principal_id         = data.azurerm_client_config.current.object_id
}