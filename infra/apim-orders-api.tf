resource "azurerm_api_management_api" "orders" {
  name                  = "orders-api"
  api_management_name   = azurerm_api_management.main.name
  resource_group_name   = azurerm_resource_group.main.name
  revision              = "1"
  display_name          = "Orders API"
  description           = "Accepts customer orders for asynchronous processing"
  path                  = "orders"
  protocols             = ["https"]
  subscription_required = true
}

# JSON schema for a valid order — APIM rejects anything that doesn't match
resource "azurerm_api_management_api_schema" "order" {
  api_name            = azurerm_api_management_api.orders.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  schema_id           = "order-schema"
  content_type        = "application/vnd.oai.openapi.components+json"

  components = jsonencode({
    schemas = {
      Order = {
        type                 = "object"
        required             = ["customerId", "items"]
        additionalProperties = false
        properties = {
          orderId    = { type = "string", maxLength = 64 }
          customerId = { type = "string", minLength = 1, maxLength = 64 }
          items = {
            type     = "array"
            minItems = 1
            maxItems = 50
            items = {
              type     = "object"
              required = ["sku", "qty"]
              properties = {
                sku = { type = "string", minLength = 1, maxLength = 32 }
                qty = { type = "integer", minimum = 1, maximum = 1000 }
              }
            }
          }
        }
      }
    }
  })
}

resource "azurerm_api_management_api_operation" "create_order" {
  operation_id        = "create-order"
  api_name            = azurerm_api_management_api.orders.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  display_name        = "Create order"
  method              = "POST"
  url_template        = "/"
  description         = "Submit a new order. Returns 202 when queued."

  request {
    representation {
      content_type = "application/json"
      schema_id    = azurerm_api_management_api_schema.order.schema_id
      type_name    = "Order"
    }
  }

  response {
    status_code = 202
  }
  response {
    status_code = 400
  }
  response {
    status_code = 429
  }
}


resource "azurerm_api_management_api_operation_policy" "create_order" {
  api_name            = azurerm_api_management_api.orders.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  operation_id        = azurerm_api_management_api_operation.create_order.operation_id

  xml_content = <<-XML
    <policies>
      <inbound>
        <base />
         <rate-limit calls="10" renewal-period="60" />

        <validate-content unspecified-content-type-action="prevent" max-size="4096" size-exceeded-action="prevent">
          <content type="application/json" validate-as="json" action="prevent" />
        </validate-content>

        <set-backend-service backend-id="${azurerm_api_management_backend.func.name}" />
        <rewrite-uri template="/orders" />
      </inbound>
      <backend>
        <base />
      </backend>
      <outbound>
        <base />
      </outbound>
      <on-error>
        <base />
      </on-error>
    </policies>
  XML
}


resource "azurerm_api_management_product" "partners" {
  product_id            = "partners"
  api_management_name   = azurerm_api_management.main.name
  resource_group_name   = azurerm_resource_group.main.name
  display_name          = "Partners"
  description           = "External partners submitting orders"
  subscription_required = true
  approval_required     = false
  published             = true
}

resource "azurerm_api_management_product_api" "partners_orders" {
  api_name            = azurerm_api_management_api.orders.name
  product_id          = azurerm_api_management_product.partners.product_id
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
}

# A test client subscription so we can call the API
resource "azurerm_api_management_subscription" "test_client" {
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  product_id          = azurerm_api_management_product.partners.id
  display_name        = "Test Client"
  state               = "active"
}