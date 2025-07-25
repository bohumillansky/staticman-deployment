#!/bin/bash

set -e

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found. Run ./scripts/setup.sh first."
    exit 1
fi

# Validate required environment variables
if [ -z "$GITHUB_TOKEN" ] || [ -z "$RSA_PRIVATE_KEY" ]; then
    echo "❌ Error: Missing required environment variables"
    echo "GITHUB_TOKEN length: ${#GITHUB_TOKEN}"
    echo "RSA_PRIVATE_KEY length: ${#RSA_PRIVATE_KEY}"
    echo "Please check your .env file"
    exit 1
fi

echo "🔍 Environment check:"
echo "  GITHUB_TOKEN: ${GITHUB_TOKEN:0:10}... (${#GITHUB_TOKEN} chars)"
echo "  RSA_PRIVATE_KEY: ${RSA_PRIVATE_KEY:0:20}... (${#RSA_PRIVATE_KEY} chars)"

echo "🛑 Stopping existing services..."
docker-compose down 2>/dev/null || true

echo "🏗️  Building Staticman image..."
docker-compose build --no-cache staticman

echo "🚀 Starting services..."
docker-compose up -d

echo "⏳ Waiting for services to start..."
sleep 10

# Monitor startup
for i in {1..12}; do
    echo "🔍 Checking service status ($i/12)..."
    
    # Check container status
    STATICMAN_STATUS=$(docker-compose ps --services --filter "status=running" | grep staticman || echo "")
    NGINX_STATUS=$(docker-compose ps --services --filter "status=running" | grep nginx || echo "")
    
    if [ -n "$STATICMAN_STATUS" ] && [ -n "$NGINX_STATUS" ]; then
        echo "✅ All services are running!"
        break
    else
        echo "⏳ Services still starting..."
        docker-compose ps
        echo "Staticman logs:"
        docker-compose logs --tail 3 staticman
    fi
    
    if [ $i -eq 12 ]; then
        echo "⚠️  Services taking longer than expected to start"
        echo "Check logs with: docker-compose logs staticman"
    fi
    
    sleep 5
done

echo ""
echo "📊 Final status:"
docker-compose ps

# Test connectivity
echo ""
echo "🌐 Testing connectivity..."
EXTERNAL_IP=$(curl -s ifconfig.me 2>/dev/null || echo "Unable to determine external IP")
if [ "$EXTERNAL_IP" != "Unable to determine external IP" ]; then
    echo "🔗 Staticman API endpoint: http://$EXTERNAL_IP/v3/"
    
    # Quick health check
    if curl -s --max-time 5 "http://localhost/health" >/dev/null 2>&1; then
        echo "✅ Health check passed!"
    else
        echo "⚠️  Health check failed - service may still be starting"
    fi
fi

echo ""
echo "🎉 Deployment complete!"
echo ""
echo "📊 Monitor services:"
echo "  docker-compose ps"
echo "  docker-compose logs -f staticman"
echo "  docker-compose logs -f nginx"
echo ""
echo "🔧 Manage services:"
echo "  docker-compose restart staticman  # Restart service"
echo "  docker-compose down              # Stop all services"
echo "  docker-compose up -d             # Start all services"

# Clean up old images
echo ""
echo "🧹 Cleaning up old images..."
docker image prune -f
echo "✅ Cleanup complete"
