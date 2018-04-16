import json


def main_handler(event, context):
    try:
        fail = event['queryStringParameters']['fail']
    except (KeyError, TypeError):
        pass
    else:
        if fail:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Failing as requested.'})
            }

    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps({'message': 'Success.'})
    }
