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
    echo "Please ensure GITHUB_TOKEN and RSA_PRIVATE_KEY are set in .env"
    exit 1
fi

# Create Staticman production config from template
echo "📝 Creating Staticman production config..."
envsubst < configs/production.json.template > configs/production.json

echo "✅ Setup complete! You can now deploy with:"
echo "  ./scripts/deploy.sh"
