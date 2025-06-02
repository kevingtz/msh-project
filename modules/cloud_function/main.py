import os
import json
from typing import Any


def hello_world(request: Any) -> str:
    """
    Cloud Function entry point that returns a hello world message.
    Following Clean Architecture principles, this function is independent
    of the cloud provider and contains only business logic.
    
    Args:
        request: Flask request object (HTTP trigger)
        
    Returns:
        str: Hello World message with environment information
    """
    # Get environment from environment variable
    environment = os.environ.get('ENV', 'unknown')
    
    # Business logic - independent of cloud provider
    message = _generate_hello_message(environment)
    
    # Handle CORS for browser requests
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type'
    }
    
    # Handle preflight requests
    if request.method == 'OPTIONS':
        return ('', 204, headers)
    
    # Return response with headers
    return (message, 200, headers)


def _generate_hello_message(environment: str) -> str:
    """
    Pure business logic function to generate hello message.
    This is testable and independent of any framework.
    
    Args:
        environment: The environment name
        
    Returns:
        str: Formatted hello message
    """
    return f"Hello, World! Environment: {environment}"


# For local testing
if __name__ == "__main__":
    # Mock request object for testing
    class MockRequest:
        method = 'GET'
    
    result = hello_world(MockRequest())
    print(result) 