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
        name = "managedIdentityAuth"
        values = {
          storageaccount = { value = azurerm_storage_account.data.name }
        }
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
      state = "Enabled"
      definition = {
        "$schema"      = "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#"
        contentVersion = "1.0.0.0"
        parameters     = {}
        triggers       = {}
        actions        = {}
        outputs        = {}
      }
      parameters = {}
    }
  }
}