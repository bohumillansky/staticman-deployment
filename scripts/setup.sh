#!/bin/bash

set -e

echo "Setting up Staticman deployment..."

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Creating .env file from template..."
    cp .env.example .env
    echo "Please edit .env file with your actual values before proceeding."
    exit 1
fi

# Load environment variables
source .env

# Validate required environment variables
if [ -z "$GITHUB_APP_ID" ] || [ -z "$GITHUB_PRIVATE_KEY" ] || [ -z "$WEBHOOK_SECRET" ]; then
    echo "❌ Error: Missing required GitHub App environment variables"
    echo "GITHUB_APP_ID: ${GITHUB_APP_ID:-'not set'}"
    echo "GITHUB_PRIVATE_KEY length: ${#GITHUB_PRIVATE_KEY}"
    echo "WEBHOOK_SECRET: ${WEBHOOK_SECRET:+set}"
    echo ""
    echo "Please configure your .env file with GitHub App credentials:"
    echo "1. GITHUB_APP_ID - from your GitHub App settings"
    echo "2. GITHUB_PRIVATE_KEY - content of your downloaded .pem file"
    echo "3. WEBHOOK_SECRET - secret you set when creating the app"
    exit 1
fi

echo "✅ GitHub App credentials loaded:"
echo "  App ID: $GITHUB_APP_ID"
echo "  Private Key: ${GITHUB_PRIVATE_KEY:0:30}... (${#GITHUB_PRIVATE_KEY} chars)"
echo "  Webhook Secret: configured"

# Create Staticman production config
echo "📝 Creating Staticman production config..."

if [ ! -f configs/production.json.template ]; then
    echo "❌ Error: configs/production.json.template not found"
    exit 1
fi

# Create config from template
cat > configs/production.json << EOF
{
  "githubAppID": "${GITHUB_APP_ID}",
  "githubPrivateKey": "${GITHUB_PRIVATE_KEY}",
  "port": 8080,
  "webhookSecret": "${WEBHOOK_SECRET}"
}
EOF

# Verify the config was created correctly
if [ -f configs/production.json ]; then
    CONFIG_SIZE=$(wc -c < configs/production.json)
    if [ "$CONFIG_SIZE" -gt 100 ]; then
        echo "✅ Production config created successfully ($CONFIG_SIZE bytes)"
    else
        echo "❌ Production config seems too small, check your environment variables"
        cat configs/production.json
        exit 1
    fi
else
    echo "❌ Failed to create production config"
    exit 1
fi

echo "✅ Setup complete! You can now deploy with:"
echo "  ./scripts/deploy.sh"
