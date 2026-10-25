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