resource "random_string" "suffix" {
  length  = 4
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_storage_account" "func" {
  name                     = "st${var.project}${var.environment}fn${random_string.suffix.result}"
  location                 = azurerm_resource_group.main.location
  resource_group_name      = azurerm_resource_group.main.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = var.tags
}

resource "azurerm_service_plan" "func" {
  name                = "asp-${local.name_prefix}-func"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = "Y1"
  tags                = var.tags
}

resource "azurerm_linux_function_app" "main" {
  name                = "func-${local.name_prefix}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.func.id

  storage_account_name       = azurerm_storage_account.func.name
  storage_account_access_key = azurerm_storage_account.func.primary_access_key

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_insights_connection_string = azurerm_application_insights.main.connection_string
    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"                      = "python"
    "SERVICEBUS_FQDN"                               = "${azurerm_servicebus_namespace.main.name}.servicebus.windows.net"
    "ORDERS_QUEUE_NAME"                             = azurerm_servicebus_queue.orders.name
    "APPLICATIONINSIGHTS_CONNECTION_STRING"         = azurerm_application_insights.main.connection_string
    "ServiceBusConnection__fullyQualifiedNamespace" = "${azurerm_servicebus_namespace.main.name}.servicebus.windows.net"
    "DATA_STORAGE_ACCOUNT"                          = azurerm_storage_account.data.name
  }

  tags = var.tags
}

# The host needs ~1 minute after creation before its keys can be read
resource "time_sleep" "function_host_ready" {
  depends_on      = [azurerm_linux_function_app.main]
  create_duration = "60s"
}