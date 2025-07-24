#!/bin/bash

set -e

echo "Generating RSA key pair for Staticman..."

# Generate RSA key pair
openssl genrsa -out staticman_private.pem 2048
openssl rsa -in staticman_private.pem -pubout -out staticman_public.pem

echo "Keys generated:"
echo "- Private key: staticman_private.pem"
echo "- Public key: staticman_public.pem"
echo ""
echo "Add the PUBLIC key to your GitHub repository as a deploy key with write access."
echo "Copy the PRIVATE key content to your .env file."
echo ""
echo "Public key content:"
cat staticman_public.pem
echo ""
echo "Private key content (for .env file):"
cat staticman_private.pem
