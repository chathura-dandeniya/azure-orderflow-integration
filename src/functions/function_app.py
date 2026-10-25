import json
import logging
import os
import uuid
from datetime import datetime, timezone

import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.servicebus import ServiceBusClient, ServiceBusMessage

app = func.FunctionApp()

REQUIRED_FIELDS = {"customerId", "items"}


@app.route(route="orders", methods=["POST"], auth_level=func.AuthLevel.FUNCTION)
def order_intake(req: func.HttpRequest) -> func.HttpResponse:
    """Accept an order over HTTP, validate it, and put it on the Service Bus queue."""
    logging.info("OrderIntake: request received")

    # 1. Parse the body
    try:
        body = req.get_json()
    except ValueError:
        return _error(400, "Request body must be valid JSON")

    # 2. Validate
    missing = REQUIRED_FIELDS - body.keys()
    if missing:
        return _error(400, f"Missing fields: {', '.join(sorted(missing))}")
    if not isinstance(body["items"], list) or not body["items"]:
        return _error(400, "items must be a non-empty list")

    # 3. Enrich — add an ID and a timestamp
    order_id = body.get("orderId") or str(uuid.uuid4())
    order = {
        "orderId": order_id,
        "customerId": body["customerId"],
        "items": body["items"],
        "receivedAt": datetime.now(timezone.utc).isoformat(),
        "status": "Received",
    }

    # 4. Publish to the queue
    try:
        _send_to_queue(order)
    except Exception:
        logging.exception("OrderIntake: failed to send to Service Bus")
        return _error(503, "Order could not be queued, please retry")

    logging.info("OrderIntake: order %s queued", order_id)
    return func.HttpResponse(
        json.dumps({"orderId": order_id, "status": "Accepted"}),
        status_code=202,
        mimetype="application/json",
    )


def _send_to_queue(order: dict) -> None:
    fqdn = os.environ["SERVICEBUS_FQDN"]
    queue_name = os.environ["ORDERS_QUEUE_NAME"]

    credential = DefaultAzureCredential()
    with ServiceBusClient(fqdn, credential) as client:
        with client.get_queue_sender(queue_name) as sender:
            message = ServiceBusMessage(
                json.dumps(order),
                message_id=order["orderId"],       # used by duplicate detection
                content_type="application/json",
                application_properties={"source": "order-intake"},
            )
            sender.send_messages(message)


def _error(status: int, message: str) -> func.HttpResponse:
    return func.HttpResponse(
        json.dumps({"error": message}),
        status_code=status,
        mimetype="application/json",
    )


# ---------------------------------------------------------------------------
# CheckInventory — called by the Logic App. Simulates a stock system.
# ---------------------------------------------------------------------------
INVENTORY = {
    "BOOK-01": 25,
    "PEN-05": 500,
    "MUG-07": 0,       # out of stock -> order will be rejected
    "X": 10,
}


@app.route(route="inventory/check", methods=["POST"], auth_level=func.AuthLevel.FUNCTION)
def check_inventory(req: func.HttpRequest) -> func.HttpResponse:
    """Return whether every item in the order is in stock."""
    try:
        body = req.get_json()
    except ValueError:
        return _error(400, "Request body must be valid JSON")

    items = body.get("items", [])
    if not isinstance(items, list) or not items:
        return _error(400, "items must be a non-empty list")

    results = []
    all_in_stock = True
    for item in items:
        sku = item.get("sku", "")
        qty = int(item.get("qty", 0))
        available = INVENTORY.get(sku, 0)
        in_stock = available >= qty
        all_in_stock = all_in_stock and in_stock
        results.append({"sku": sku, "requested": qty, "available": available, "inStock": in_stock})

    logging.info("CheckInventory: order %s approved=%s", body.get("orderId"), all_in_stock)
    return func.HttpResponse(
        json.dumps({"orderId": body.get("orderId"), "approved": all_in_stock, "items": results}),
        status_code=200,
        mimetype="application/json",
    )


# ---------------------------------------------------------------------------
# NotifyCustomer — subscribed to the Event Grid topic. Simulates an email.
# ---------------------------------------------------------------------------
@app.event_grid_trigger(arg_name="event")
def notify_customer(event: func.EventGridEvent) -> None:
    data = event.get_json()
    order_id = data.get("orderId")
    customer_id = data.get("customerId")

    if event.event_type == "OrderFlow.OrderApproved":
        message = f"Hi {customer_id}, your order {order_id} is confirmed and on its way."
    elif event.event_type == "OrderFlow.OrderRejected":
        out_of_stock = [i["sku"] for i in data.get("inventory", []) if not i.get("inStock")]
        message = f"Hi {customer_id}, order {order_id} could not be fulfilled. Out of stock: {', '.join(out_of_stock)}"
    else:
        logging.warning("NotifyCustomer: unexpected event type %s", event.event_type)
        return

    # In production this would call an email service (Azure Communication Services, SendGrid).
    logging.info("NotifyCustomer: EMAIL TO %s | %s", customer_id, message)

    

# ---------------------------------------------------------------------------
# DeadLetterHandler — drains orders/$DeadLetterQueue and records the failure.
# ---------------------------------------------------------------------------
from azure.data.tables import TableServiceClient, UpdateMode


@app.service_bus_queue_trigger(
    arg_name="msg",
    queue_name="orders/$DeadLetterQueue",
    connection="ServiceBusConnection",
)
def dead_letter_handler(msg: func.ServiceBusMessage) -> None:
    message_id = msg.message_id or "unknown"
    reason = getattr(msg, "dead_letter_reason", None) or "Unknown"
    description = getattr(msg, "dead_letter_error_description", None) or ""
    raw_body = msg.get_body().decode("utf-8", errors="replace")

    logging.error(
        "DeadLetterHandler: message %s dead-lettered. reason=%s detail=%s body=%s",
        message_id, reason, description, raw_body[:500],
    )

    # Try to recover the ids from the body; fall back to the message id
    try:
        order = json.loads(raw_body)
        partition_key = order.get("customerId", "unknown")
        row_key = order.get("orderId", message_id)
    except (ValueError, AttributeError):
        partition_key = "unknown"
        row_key = message_id

    account = os.environ["DATA_STORAGE_ACCOUNT"]
    service = TableServiceClient(
        endpoint=f"https://{account}.table.core.windows.net",
        credential=DefaultAzureCredential(),
    )
    table = service.get_table_client("orders")
    table.upsert_entity(
        mode=UpdateMode.REPLACE,
        entity={
            "PartitionKey": partition_key,
            "RowKey": row_key,
            "Status": "Failed",
            "FailureReason": reason,
            "FailureDetail": description[:1000],
            "RawBody": raw_body[:1000],
            "ProcessedAt": datetime.now(timezone.utc).isoformat(),
        },
    )