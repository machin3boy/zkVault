import os
import time
import json
import boto3
from web3 import Web3
from eth_account.messages import encode_defunct
from eth_account import Account
import pyotp

def to_32byte_hex(val):
    return Web3.to_hex(Web3.to_bytes(val).rjust(32, b'\0'))

w3 = Web3()

def sign_message(private_key, message):
    # Encode the message
    encoded_message = encode_defunct(text=message)
    # Convert private key from string to bytes
    private_key_bytes = bytes.fromhex(private_key)
    # Sign the message
    signed_message = w3.eth.account.sign_message(encoded_message, private_key=private_key_bytes)
    return signed_message

def recover_signature(signed_message):
    # Extract the necessary components
    msg_hash = Web3.to_hex(signed_message.messageHash)
    v = signed_message.v
    r = to_32byte_hex(signed_message.r)
    s = to_32byte_hex(signed_message.s)
    return msg_hash, v, r, s

# Read private keys from environment variables
private_key_one = os.environ.get("PRIVATE_KEY_ONE")
private_key_two = os.environ.get("PRIVATE_KEY_TWO")

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
secrets_table = dynamodb.Table('UsernameSecrets')

def lambda_handler(event, context):
    if event['path'] == '/register':
        if event['httpMethod'] == 'POST':
            body = json.loads(event['body'])
            username = body['username']
            
            # Check if the username exists in DynamoDB
            response = secrets_table.get_item(Key={'username': username})
            if 'Item' not in response:
                # Generate secrets for the user if they don't exist
                secret_one = pyotp.random_base32()
                secret_two = pyotp.random_base32()
                
                # Store the secrets in DynamoDB
                secrets_table.put_item(Item={
                    'username': username,
                    'secret_one': secret_one,
                    'secret_two': secret_two
                })
            else:
                # Retrieve the existing secrets for the user
                secret_one = response['Item']['secret_one']
                secret_two = response['Item']['secret_two']
            
            # Generate QR code URIs for the provisioners
            totp_one = pyotp.TOTP(secret_one)
            totp_two = pyotp.TOTP(secret_two)
            qr_uri_one = totp_one.provisioning_uri(name=f"{username}@Google MFA zkVault", issuer_name="Google MFA zkVault")
            qr_uri_two = totp_two.provisioning_uri(name=f"{username}@Microsoft MFA zkVault", issuer_name="Microsoft MFA zkVault")
            
            response = {
                'statusCode': 200,
                'body': json.dumps({
                    'qr_uri_one': qr_uri_one,
                    'qr_uri_two': qr_uri_two
                })
            }
            return response
    
    elif event['path'] == '/sign':
        if event['httpMethod'] == 'POST':
            body = json.loads(event['body'])
            username = body['username']
            otp_secret_one = body.get('otp_secret_one')
            otp_secret_two = body.get('otp_secret_two')
            request_id = body['request_id']
            
            # Retrieve the secrets from DynamoDB
            response = secrets_table.get_item(Key={'username': username})

            if 'Item' in response:
                secret_one = response['Item']['secret_one']
                secret_two = response['Item']['secret_two']
                
                totp_one = pyotp.TOTP(secret_one)
                totp_two = pyotp.TOTP(secret_two)
                
                timestamp = int(time.time())
                message = f"{username}-{request_id}-{timestamp}"
                
                signed_messages = {}
                
                if otp_secret_one and totp_one.verify(otp_secret_one):
                    signed_message_one = sign_message(private_key_one, message)
                    msg_hash_one, v_one, r_one, s_one = recover_signature(signed_message_one)
                    signed_messages['signed_message_one'] = {
                        'message': message,
                        'msg_hash': msg_hash_one,
                        'v': v_one,
                        'r': r_one,
                        's': s_one
                    }
                
                if otp_secret_two and totp_two.verify(otp_secret_two):
                    signed_message_two = sign_message(private_key_two, message)
                    msg_hash_two, v_two, r_two, s_two = recover_signature(signed_message_two)
                    signed_messages['signed_message_two'] = {
                        'message': message,
                        'msg_hash': msg_hash_two,
                        'v': v_two,
                        'r': r_two,
                        's': s_two
                    }
                
                if signed_messages:
                    response = {
                        'statusCode': 200,
                        'body': json.dumps(signed_messages)
                    }
                    return response
                else:
                    response = {
                        'statusCode': 401,
                        'body': json.dumps({'error': 'Invalid OTP secrets'})
                    }
                    return response
            else:
                response = {
                    'statusCode': 401,
                    'body': json.dumps({'error': 'Username not registered'})
                }
                return response
    
    response = {
        'statusCode': 404,
        'body': json.dumps({'error': 'Invalid endpoint'})
    }
    return response