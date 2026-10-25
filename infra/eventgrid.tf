# Custom topic the Logic App publishes order events to
resource "azurerm_eventgrid_topic" "orders" {
  name                = "evgt-${local.name_prefix}-orders"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  input_schema        = "EventGridSchema"
  local_auth_enabled  = false # keys disabled: publishers must use Entra ID / managed identity

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}


# Subscriber 1: NotifyCustomer Function — gets BOTH approved and rejected events
resource "azurerm_eventgrid_event_subscription" "notify_customer" {
  name  = "evgs-notify-customer"
  scope = azurerm_eventgrid_topic.orders.id
  count = var.deploy_function_subscriptions ? 1 : 0

  azure_function_endpoint {
    function_id                       = "${azurerm_linux_function_app.main.id}/functions/notify_customer"
    max_events_per_batch              = 1
    preferred_batch_size_in_kilobytes = 64
  }

  included_event_types = ["OrderFlow.OrderApproved", "OrderFlow.OrderRejected"]

  retry_policy {
    max_delivery_attempts = 10
    event_time_to_live    = 1440 # minutes = 24h
  }
}

# Subscriber 2: Warehouse Service Bus topic — ONLY approved orders, delivered via managed identity
resource "azurerm_eventgrid_event_subscription" "warehouse" {
  name  = "evgs-warehouse"
  scope = azurerm_eventgrid_topic.orders.id

  service_bus_topic_endpoint_id = azurerm_servicebus_topic.warehouse.id

  delivery_identity {
    type = "SystemAssigned"
  }

  included_event_types = ["OrderFlow.OrderApproved"]

  retry_policy {
    max_delivery_attempts = 10
    event_time_to_live    = 1440
  }

  depends_on = [azurerm_role_assignment.eg_sb_sender]
}