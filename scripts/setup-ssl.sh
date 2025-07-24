
#!/bin/bash

set -e

echo "Setting up SSL for Staticman..."

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Error: .env file not found. Run ./scripts/setup.sh first."
    exit 1
fi

# Load environment variables
source .env

# Check required variables
if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    echo "Error: DOMAIN and EMAIL must be set in .env file for SSL setup."
    echo "Add these lines to your .env file:"
    echo "DOMAIN=your-domain.com"
    echo "EMAIL=your-email@example.com"
    exit 1
fi

echo "Setting up SSL for domain: $DOMAIN"
echo "Email: $EMAIL"

# Create nginx SSL config
sed "s/your-domain.com/$DOMAIN/g" configs/nginx-ssl.conf > /tmp/nginx-ssl-configured.conf

# Create Docker configs
echo "Creating Docker configs..."
docker config create nginx_ssl_config /tmp/nginx-ssl-configured.conf 2>/dev/null || echo "Config nginx_ssl_config already exists"

# Clean up temp file
rm /tmp/nginx-ssl-configured.conf

echo "SSL setup complete! You can now deploy with SSL using:"
echo "  docker stack deploy -c docker-compose.ssl.yml $STACK_NAME"
echo ""
echo "Note: Make sure your domain DNS is pointing to this server's IP address."
echo "Server IP: $(curl -s ifconfig.me)"
