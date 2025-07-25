#!/bin/bash

set -e

echo "Generating RSA key pair for Staticman..."

# Generate RSA key pair in traditional format first
ssh-keygen -t rsa -b 2048 -f staticman_key -N "" -C "staticman@deployment"

# Convert private key to PEM format for Staticman
ssh-keygen -p -m PEM -f staticman_key -N ""

# Copy files
cp staticman_key staticman_private.pem
cp staticman_key.pub staticman_public.pem

# Clean up
rm staticman_key staticman_key.pub

echo "✅ Keys generated:"
echo "- Private key: staticman_private.pem (PEM format for .env file)"
echo "- Public key: staticman_public.pem (OpenSSH format for GitHub Deploy Key)"
echo ""
echo "🔑 PUBLIC KEY FOR GITHUB DEPLOY KEYS:"
echo "════════════════════════════════════════════════════════════"
cat staticman_public.pem
echo "════════════════════════════════════════════════════════════"
echo ""
echo "🔑 PRIVATE KEY FOR .env FILE (PEM FORMAT):"
echo "═══════════════════════════════════════════════════════════"
echo 'RSA_PRIVATE_KEY="'$(cat staticman_private.pem | tr '\n' ' ' | sed 's/ *$//')'"'
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "📝 Next steps:"
echo "1. Add the PUBLIC key to your Hugo site repository Deploy Keys (with write access)"
echo "2. Copy the PRIVATE key line to your .env file (replace existing RSA_PRIVATE_KEY)"
echo "3. Run ./scripts/deploy.sh"
