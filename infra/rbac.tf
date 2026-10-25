# Function App -> can send messages to Service Bus
resource "azurerm_role_assignment" "func_sb_sender" {
  scope                = azurerm_servicebus_namespace.main.id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}