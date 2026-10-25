# Function App -> can send messages to Service Bus
resource "azurerm_role_assignment" "func_sb_sender" {
  scope                = azurerm_servicebus_namespace.main.id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}

data "azurerm_client_config" "current" {}
#--------------------------------------------------------------
# Developer (you) -> full data access for local testing
/*
resource "azurerm_role_assignment" "dev_sb_owner" {
  scope                = azurerm_servicebus_namespace.main.id
  role_definition_name = "Azure Service Bus Data Owner"
  principal_id         = data.azurerm_client_config.current.object_id
}
*/

resource "azurerm_role_assignment" "dev_sb_owner" {
  for_each             = var.admin_object_ids
  scope                = azurerm_servicebus_namespace.main.id
  role_definition_name = "Azure Service Bus Data Owner"
  principal_id         = each.value
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

#----------------------------------------------------------------

resource "azurerm_role_assignment" "dev_table_contributor" {
  for_each             = var.admin_object_ids
  scope                = azurerm_storage_account.data.id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = each.value
}

/*
resource "azurerm_role_assignment" "dev_table_contributor" {
  scope                = azurerm_storage_account.data.id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}
*/

#----------------------------------------------------------------

# Logic App -> can publish events to the Event Grid topic
resource "azurerm_role_assignment" "logic_eg_sender" {
  scope                = azurerm_eventgrid_topic.orders.id
  role_definition_name = "EventGrid Data Sender"
  principal_id         = azapi_resource.order_processor.identity[0].principal_id
}

# Event Grid topic -> can deliver events into Service Bus (for the warehouse topic)
resource "azurerm_role_assignment" "eg_sb_sender" {
  scope                = azurerm_servicebus_namespace.main.id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = azurerm_eventgrid_topic.orders.identity[0].principal_id
}

# -------------------------------------------------------------------------
/*
# Developer (you) -> can create/read secrets
resource "azurerm_role_assignment" "dev_kv_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

*/


resource "azurerm_role_assignment" "dev_kv_officer" {
  for_each             = var.admin_object_ids
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = each.value
}


# -------------------------------------------------------------------------

# APIM -> read-only on secrets
resource "azurerm_role_assignment" "apim_kv_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_api_management.main.identity[0].principal_id
}

# Logic App -> read-only on secrets
resource "azurerm_role_assignment" "logic_kv_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azapi_resource.order_processor.identity[0].principal_id
}

# Function App -> can receive from Service Bus (for the DLQ handler)
resource "azurerm_role_assignment" "func_sb_receiver" {
  scope                = azurerm_servicebus_namespace.main.id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}

# Function App -> can write Failed rows to the orders table
resource "azurerm_role_assignment" "func_table_contributor" {
  scope                = azurerm_storage_account.data.id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}

# Role assignments take 1-2 minutes to become effective
resource "time_sleep" "kv_rbac_propagation" {
  depends_on = [
    azurerm_role_assignment.dev_kv_officer,
    azurerm_role_assignment.apim_kv_user,
  ]
  create_duration = "90s"
}