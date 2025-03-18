import json
import time
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    logger.info(f"Function Version: {context.function_version}")

    request = event['Records'][0]['cf']['request']
    headers = request['headers']

    
    # Add timestamp for logging
    timestamp = int(time.time())
    
    # Extract request details
    viewer_info = {
        'timestamp': timestamp,
        'ip': request.get('clientIp', 'unknown'),
        'method': request.get('method', 'unknown'),
        'uri': request.get('uri', 'unknown'),
        'headers': {
            'user-agent': headers.get('user-agent', [{'value': 'unknown'}])[0]['value'],
            'referer': headers.get('referer', [{'value': 'unknown'}])[0]['value'],
            'host': headers.get('host', [{'value': 'unknown'}])[0]['value']
        },
        'all_headers': headers
    }
    
    # Log the request details
    logger.info(f"REQUEST_LOG: {json.dumps(viewer_info)}")
    
    # Check for custom auth header
    auth_header = headers.get('x-custom-auth', [{'value': ''}])[0]['value']
    logger.info(f"REQUEST_LOG: {auth_header=}")

    auth_success = (auth_header is not None and auth_header == 'your-secret-value')
    
    
    if not auth_success:
        return {
            'status': '403',
            'statusDescription': 'Forbidden',
            'headers': {
                'content-type': [{
                    'key': 'Content-Type',
                    'value': 'text/plain'
                }]
            },
            'body': 'Access Denied: missing header "x-custom-auth" or invalid value'
        }
    
    return request