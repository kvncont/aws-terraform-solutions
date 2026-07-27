import json


def lambda_handler(event, context):
    message = "hello from order service"
    return {
        "statusCode": 200,
        "body": json.dumps(message)
    }
