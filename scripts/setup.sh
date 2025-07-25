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
if [ -z "$GITHUB_TOKEN" ] || [ -z "$RSA_PRIVATE_KEY" ]; then
    echo "❌ Error: Missing required environment variables"
    echo "GITHUB_TOKEN length: ${#GITHUB_TOKEN}"
    echo "RSA_PRIVATE_KEY length: ${#RSA_PRIVATE_KEY}"
    echo "Please check your .env file"
    exit 1
fi

echo "✅ Environment variables loaded:"
echo "  GITHUB_TOKEN: ${GITHUB_TOKEN:0:10}... (${#GITHUB_TOKEN} chars)"
echo "  RSA_PRIVATE_KEY: ${RSA_PRIVATE_KEY:0:20}... (${#RSA_PRIVATE_KEY} chars)"

# Create Staticman production config
echo "📝 Creating Staticman production config..."

# Use cat with heredoc instead of envsubst (more reliable)
cat > configs/production.json << EOF
{
  "githubToken": "${GITHUB_TOKEN}",
  "rsaPrivateKey": "${RSA_PRIVATE_KEY}",
  "port": 8080
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
