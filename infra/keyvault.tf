resource "azurerm_key_vault" "main" {
  name                       = "kv-${local.name_prefix}-${random_string.suffix.result}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true # roles, not access policies
  soft_delete_retention_days = 7
  purge_protection_enabled   = false # dev only: lets terraform destroy clean up fully
  tags                       = var.tags
}

# The Function host key, stored once here. Everything else reads it from the vault.
resource "azurerm_key_vault_secret" "func_host_key" {
  name         = "func-host-key"
  value        = data.azurerm_function_app_host_keys.main.default_function_key
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"

  depends_on = [time_sleep.kv_rbac_propagation]
}