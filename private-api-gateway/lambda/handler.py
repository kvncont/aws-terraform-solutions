"""
Lambda handler - API Gateway mTLS demo
Devuelve información del request incluyendo el contexto mTLS del cliente.
"""
import json
import os
import logging
from datetime import datetime, timezone

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    logger.info("Event: %s", json.dumps(event))

    # Información del certificado de cliente — REST API v1 lo expone en identity
    request_context = event.get("requestContext", {})
    identity = request_context.get("identity", {})
    client_cert = identity.get("clientCert", {})

    path = event.get("path", "/")
    method = event.get("httpMethod", "UNKNOWN")
    query_params = event.get("queryStringParameters") or {}
    headers = event.get("headers") or {}

    body = {
        "message": "Hello from mTLS-protected Lambda!",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "path": path,
        "method": method,
        "query_params": query_params,
        "environment": os.environ.get("ENVIRONMENT", "unknown"),
        "function_name": context.function_name,
        "mtls": {
            "subject_dn": client_cert.get("subjectDN", "N/A"),
            "issuer_dn": client_cert.get("issuerDN", "N/A"),
            "serial_number": client_cert.get("serialNumber", "N/A"),
            "validity": client_cert.get("validity", {}),
        },
    }

    # Respuesta específica por path
    if path.endswith("/health"):
        body["status"] = "healthy"
        status_code = 200
    elif path.endswith("/echo"):
        try:
            body["echo"] = json.loads(event.get("body") or "{}")
        except (json.JSONDecodeError, TypeError):
            body["echo"] = event.get("body", "")
        status_code = 200
    else:
        status_code = 200

    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "X-Powered-By": "AWS Lambda + mTLS",
        },
        "body": json.dumps(body, default=str),
    }
