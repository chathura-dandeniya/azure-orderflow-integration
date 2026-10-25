resource "azurerm_monitor_action_group" "ops" {
  name                = "ag-${local.name_prefix}-ops"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "orderflow"
  tags                = var.tags

  email_receiver {
    name          = "owner"
    email_address = var.alert_email
  }
}

# Fires when anything sits in a dead-letter queue (handler down, or repeated poison)
resource "azurerm_monitor_metric_alert" "dead_letters" {
  name                = "alert-${local.name_prefix}-dead-letters"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_servicebus_namespace.main.id]
  description         = "Dead-lettered messages present in Service Bus"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.ServiceBus/namespaces"
    metric_name      = "DeadletteredMessages"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 0
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops.id
  }
}

# Fires when the Logic App has failed runs
resource "azurerm_monitor_metric_alert" "logic_failures" {
  name                = "alert-${local.name_prefix}-logicapp-failures"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azapi_resource.order_processor.id]
  description         = "OrderProcessor Logic App run failures"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Logic/workflows"
    metric_name      = "RunsFailed"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 2
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops.id
  }
}