"""Send a non-JSON message straight to the orders queue to exercise the dead-letter path."""
from azure.identity import DefaultAzureCredential
from azure.servicebus import ServiceBusClient, ServiceBusMessage

NAMESPACE = "sb-orderflow-dev.servicebus.windows.net"

with ServiceBusClient(NAMESPACE, DefaultAzureCredential()) as client:
    with client.get_queue_sender("orders") as sender:
        sender.send_messages(ServiceBusMessage("this is not json", message_id="POISON-01"))
        print("Sent POISON-01")