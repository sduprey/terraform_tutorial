"""Traite les messages de la file lab-jobs, un par un."""
import logging
import os

log = logging.getLogger()
log.setLevel(os.environ.get("NIVEAU_LOG", "INFO"))


def handler(event, context):
    messages = event.get("Records", [])
    for message in messages:
        log.info("Message reçu : %s", message["body"])
    return {"traites": len(messages)}
