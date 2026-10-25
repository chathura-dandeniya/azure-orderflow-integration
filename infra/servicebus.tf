resource "azurerm_servicebus_namespace" "main" {
  name                = "sb-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
  minimum_tls_version = "1.2"
  tags                = var.tags
}

resource "azurerm_servicebus_queue" "orders" {
  name         = "orders"
  namespace_id = azurerm_servicebus_namespace.main.id

  # Reliability settings
  max_delivery_count                   = 5
  lock_duration                        = "PT1M"
  default_message_ttl                  = "P7D"
  dead_lettering_on_message_expiration = true

  # Idempotency: same MessageId within 10 minutes is dropped
  requires_duplicate_detection            = true
  duplicate_detection_history_time_window = "PT10M"
}

resource "azurerm_servicebus_topic" "warehouse" {
  name                = "warehouse"
  namespace_id        = azurerm_servicebus_namespace.main.id
  default_message_ttl = "P7D"
}

resource "azurerm_servicebus_subscription" "fulfilment" {
  name                                 = "fulfilment"
  topic_id                             = azurerm_servicebus_topic.warehouse.id
  max_delivery_count                   = 5
  lock_duration                        = "PT1M"
  dead_lettering_on_message_expiration = true
}