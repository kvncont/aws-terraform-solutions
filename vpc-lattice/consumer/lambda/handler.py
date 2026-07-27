import json
import os
import ssl
import urllib.error
import urllib.request

from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
from botocore.session import Session


def _build_ssl_context(ca_pem):
    if not ca_pem:
        return None

    context = ssl.create_default_context()
    context.load_verify_locations(cadata=ca_pem)
    return context


def _build_signed_request(method, url, body, region, service, host):
    session = Session()
    credentials = session.get_credentials()
    if credentials is None:
        raise RuntimeError("No AWS credentials available for SigV4 signing")

    request = AWSRequest(
        method=method,
        url=url,
        data=body,
        headers={
            "content-type": "application/json",
            "host": host,
            "x-amz-content-sha256": "UNSIGNED-PAYLOAD",
        },
    )

    # VPC Lattice expects unsigned payload for SigV4 header-based auth.
    request.context["payload_signing_enabled"] = False

    SigV4Auth(credentials.get_frozen_credentials(), service, region).add_auth(request)
    return dict(request.headers.items())


def lambda_handler(event, context):
    domain = os.environ["LATTICE_DOMAIN"]
    region = os.environ.get("AWS_REGION", "us-east-1")
    service = os.environ.get("LATTICE_SERVICE_NAME", "vpc-lattice-svcs")
    ca_pem = os.environ.get("LATTICE_CA_CERT", "")

    method = os.environ.get("TARGET_METHOD", "GET").upper()
    path = os.environ.get("TARGET_PATH", "/")
    payload = event.get("payload", {}) if isinstance(event, dict) else {}
    body = json.dumps(payload).encode("utf-8") if method in {"POST", "PUT", "PATCH"} else b""

    url = f"https://{domain}{path}"
    headers = _build_signed_request(method, url, body, region, service, domain)

    request = urllib.request.Request(url=url, data=body if body else None, headers=headers, method=method)
    ssl_context = _build_ssl_context(ca_pem)
    opener = urllib.request.build_opener(urllib.request.HTTPSHandler(context=ssl_context)) if ssl_context else urllib.request.build_opener()

    try:
        with opener.open(request, timeout=15) as response:
            response_body = response.read().decode("utf-8")
            return {
                "statusCode": response.status,
                "body": response_body,
                "request": {
                    "url": url,
                    "method": method,
                },
            }
    except urllib.error.HTTPError as error:
        return {
            "statusCode": error.code,
            "body": error.read().decode("utf-8"),
            "request": {
                "url": url,
                "method": method,
            },
        }
