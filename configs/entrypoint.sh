#!/bin/sh

# Read secrets into environment variables
if [ -f /run/secrets/github_token ]; then
    export GITHUB_TOKEN=$(cat /run/secrets/github_token)
fi

if [ -f /run/secrets/rsa_private_key ]; then
    export RSA_PRIVATE_KEY=$(cat /run/secrets/rsa_private_key)
fi

# Start the application
exec "$@"
