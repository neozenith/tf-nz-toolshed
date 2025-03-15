def lambda_handler(event, context):
    request = event['Records'][0]['cf']['request']
    headers = request['headers']
    
    # Check for custom auth header
    auth_header = headers.get('x-custom-auth', [{'value': ''}])[0]['value']
    
    if not auth_header or auth_header != 'your-secret-value':
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