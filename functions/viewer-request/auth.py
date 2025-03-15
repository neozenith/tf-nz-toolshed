def lambda_handler(event, context):
    request = event['Records'][0]['cf']['request']
    
    # Extract request details
    viewer_info = {
        'ip': request.get('clientIp', 'unknown'),
        'method': request.get('method', 'unknown'),
        'uri': request.get('uri', 'unknown'),
        'headers': {
            'user-agent': request['headers'].get('user-agent', [{'value': 'unknown'}])[0]['value'],
            'referer': request['headers'].get('referer', [{'value': 'unknown'}])[0]['value'],
            'host': request['headers'].get('host', [{'value': 'unknown'}])[0]['value']
        }
    }
    
    # Check for custom auth header
    auth_header = request['headers'].get('x-custom-auth', [{'value': ''}])[0]['value']
    
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
            'body': f'''Access Denied:
            IP: {viewer_info['ip']}
            Method: {viewer_info['method']}
            URI: {viewer_info['uri']}
            User-Agent: {viewer_info['headers']['user-agent']}
            Referer: {viewer_info['headers']['referer']}
            Host: {viewer_info['headers']['host']}
            '''
        }
    
    # Add viewer info to custom headers for debugging
    request['headers']['x-viewer-ip'] = [{'key': 'X-Viewer-IP', 'value': viewer_info['ip']}]
    request['headers']['x-viewer-user-agent'] = [{'key': 'X-Viewer-User-Agent', 'value': viewer_info['headers']['user-agent']}]
    
    return request