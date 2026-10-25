resource "azurerm_api_management" "main" {
  name                = "apim-${local.name_prefix}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  publisher_name      = "OrderFlow"
  publisher_email     = "chaturadh@gmail.com"
  sku_name            = "Consumption_0"

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Read the Function App host key (works for every function in the app)
data "azurerm_function_app_host_keys" "main" {
  name                = azurerm_linux_function_app.main.name
  resource_group_name = azurerm_resource_group.main.name
  depends_on          = [time_sleep.function_host_ready]
}

/*
resource "azurerm_api_management_named_value" "func_key" {
  name                = "func-host-key"
  display_name        = "func-host-key"
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  secret              = true
  # value               = data.azurerm_function_app_host_keys.main.default_function_key
}
*/

# Backend = the Function App. APIM adds the key header on every call.
resource "azurerm_api_management_backend" "func" {
  name                = "orderintake-func"
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  protocol            = "http"
  url                 = "https://${azurerm_linux_function_app.main.default_hostname}/api"

  credentials {
    header = {
      "x-functions-key" = "{{func-host-key}}"
    }
  }
}


resource "azurerm_api_management_named_value" "func_key" {
  name                = "func-host-key"
  display_name        = "func-host-key"
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  secret              = true

  value_from_key_vault {
    secret_id = azurerm_key_vault_secret.func_host_key.versionless_id
  }

  depends_on = [time_sleep.kv_rbac_propagation]
}

