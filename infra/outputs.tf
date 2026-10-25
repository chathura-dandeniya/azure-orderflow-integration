output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "function_app_name" {
  value = azurerm_linux_function_app.main.name
}

output "function_app_hostname" {
  value = azurerm_linux_function_app.main.default_hostname
}

output "servicebus_namespace" {
  value = azurerm_servicebus_namespace.main.name
}

output "apim_gateway_url" {
  value = azurerm_api_management.main.gateway_url
}

output "apim_test_subscription_key" {
  value     = azurerm_api_management_subscription.test_client.primary_key
  sensitive = true
}

output "data_storage_account" {
  value = azurerm_storage_account.data.name
}

output "logic_app_name" {
  value = azapi_resource.order_processor.name
}