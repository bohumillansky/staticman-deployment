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

# Create Docker configs
echo "Creating Docker configs..."
docker config create nginx_config configs/nginx.conf 2>/dev/null || echo "Config nginx_config already exists"

echo "Setup complete! You can now deploy with:"
echo "  ./scripts/deploy.sh"
