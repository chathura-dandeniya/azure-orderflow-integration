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

# Logic App -> can receive from Service Bus
resource "azurerm_role_assignment" "logic_sb_receiver" {
  scope                = azurerm_servicebus_namespace.main.id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = azapi_resource.order_processor.identity[0].principal_id
}

# Logic App -> can write to the orders table
resource "azurerm_role_assignment" "logic_table_contributor" {
  scope                = azurerm_storage_account.data.id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = azapi_resource.order_processor.identity[0].principal_id
}