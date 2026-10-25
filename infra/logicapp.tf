locals {
  managed_api_base = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Web/locations/${var.location}/managedApis"
}

# --- API connections (managed identity, no secrets) -------------------------

resource "azapi_resource" "conn_servicebus" {
  type      = "Microsoft.Web/connections@2016-06-01"
  name      = "servicebus-mi"
  location  = azurerm_resource_group.main.location
  parent_id = azurerm_resource_group.main.id
  tags      = var.tags

  schema_validation_enabled = false

  body = {
    properties = {
      displayName = "Service Bus (managed identity)"
      api         = { id = "${local.managed_api_base}/servicebus" }
      parameterValueSet = {
        name = "managedIdentityAuth"
        values = {
          namespaceEndpoint = { value = "sb://${azurerm_servicebus_namespace.main.name}.servicebus.windows.net/" }
        }
      }
    }
  }
}

resource "azapi_resource" "conn_tables" {
  type      = "Microsoft.Web/connections@2016-06-01"
  name      = "azuretables-mi"
  location  = azurerm_resource_group.main.location
  parent_id = azurerm_resource_group.main.id
  tags      = var.tags

  schema_validation_enabled = false

  body = {
    properties = {
      displayName = "Azure Tables (managed identity)"
      api         = { id = "${local.managed_api_base}/azuretables" }
      parameterValueSet = {
        name   = "managedIdentityAuth"
        values = {}
      }
    }
  }
}

# --- Logic App (Consumption). Empty definition for now; Step 4 fills it. ----

resource "azapi_resource" "order_processor" {
  type      = "Microsoft.Logic/workflows@2019-05-01"
  name      = "logic-${local.name_prefix}-orderprocessor"
  location  = azurerm_resource_group.main.location
  parent_id = azurerm_resource_group.main.id
  tags      = var.tags

  identity {
    type = "SystemAssigned"
  }

  body = {
    properties = {
      state      = "Enabled"
      definition = jsondecode(file("${path.module}/../workflows/orderprocessor.json"))
      parameters = {
        "$connections" = {
          value = {
            servicebus = {
              connectionId   = azapi_resource.conn_servicebus.id
              connectionName = azapi_resource.conn_servicebus.name
              id             = "${local.managed_api_base}/servicebus"
              connectionProperties = {
                authentication = { type = "ManagedServiceIdentity" }
              }
            }
            azuretables = {
              connectionId   = azapi_resource.conn_tables.id
              connectionName = azapi_resource.conn_tables.name
              id             = "${local.managed_api_base}/azuretables"
              connectionProperties = {
                authentication = { type = "ManagedServiceIdentity" }
              }
            }


            keyvault = {
              connectionId   = azapi_resource.conn_keyvault.id
              connectionName = azapi_resource.conn_keyvault.name
              id             = "${local.managed_api_base}/keyvault"
              connectionProperties = {
                authentication = { type = "ManagedServiceIdentity" }
              }
            }

          }
        }
        functionBaseUrl = { value = "https://${azurerm_linux_function_app.main.default_hostname}" }
        # functionKey            = { value = data.azurerm_function_app_host_keys.main.default_function_key }
        storageAccountName     = { value = azurerm_storage_account.data.name }
        eventGridTopicEndpoint = { value = azurerm_eventgrid_topic.orders.endpoint }
      }
    }
  }
}

resource "azapi_resource" "conn_keyvault" {
  type      = "Microsoft.Web/connections@2016-06-01"
  name      = "keyvault-mi"
  location  = azurerm_resource_group.main.location
  parent_id = azurerm_resource_group.main.id
  tags      = var.tags

  schema_validation_enabled = false

  body = {
    properties = {
      displayName = "Key Vault (managed identity)"
      api         = { id = "${local.managed_api_base}/keyvault" }
      parameterValueSet = {
        name = "oauthMI"
        values = {
          vaultName = { value = azurerm_key_vault.main.name }
        }
      }
    }
  }
}