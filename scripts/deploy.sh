#!/bin/bash

set -e

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found. Run ./scripts/setup.sh first."
    exit 1
fi

# Validate GitHub App credentials
if [ -z "$GITHUB_APP_ID" ] || [ -z "$GITHUB_PRIVATE_KEY" ] || [ -z "$GITHUB_WEBHOOK_SECRET" ]; then
    echo "❌ Error: Missing required GitHub App environment variables"
    echo "Please run ./scripts/setup.sh first"
    exit 1
fi

echo "🔍 GitHub App credentials:"
echo "  App ID: $GITHUB_APP_ID"
echo "  Private Key: ${GITHUB_PRIVATE_KEY:0:30}... (${#GITHUB_PRIVATE_KEY} chars)"
echo "  Webhook Secret: configured"

echo "🛑 Stopping existing services..."
docker-compose down 2>/dev/null || true

# Smart image building
echo "🏗️  Checking if image rebuild is needed..."
IMAGE_EXISTS=$(docker images -q staticman-deployment-staticman 2>/dev/null)
DOCKERFILE_CHANGED=false

if [ -n "$IMAGE_EXISTS" ]; then
    if [ -f Dockerfile ]; then
        DOCKERFILE_AGE=$(find Dockerfile -mmin -5 2>/dev/null | wc -l)
        if [ "$DOCKERFILE_AGE" -gt 0 ]; then
            DOCKERFILE_CHANGED=true
        fi
    fi
fi

FORCE_REBUILD=false
if [ "$1" = "--rebuild" ] || [ "$1" = "-r" ]; then
    FORCE_REBUILD=true
    echo "🔄 Force rebuild requested"
fi

if [ -z "$IMAGE_EXISTS" ] || [ "$DOCKERFILE_CHANGED" = true ] || [ "$FORCE_REBUILD" = true ]; then
    echo "🏗️  Building Staticman image..."
    docker-compose build staticman
else
    echo "✅ Using existing Staticman image (use --rebuild to force rebuild)"
fi

echo "🚀 Starting services..."
docker-compose up -d

echo "⏳ Waiting for services to start..."
sleep 10

# Monitor startup
for i in {1..12}; do
    echo "🔍 Checking service status ($i/12)..."
    
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
    echo "🔗 Staticman API: http://$EXTERNAL_IP/v2/entry/bohumillansky/zivotvusa.cz/main/comments"
    echo "🔗 Connect endpoint: http://$EXTERNAL_IP/v2/connect/bohumillansky/zivotvusa.cz"
    
    if curl -s --max-time 5 "http://localhost/health" >/dev/null 2>&1; then
        echo "✅ Health check passed!"
    else
        echo "⚠️  Health check failed - service may still be starting"
    fi
    
    API_TEST=$(curl -s "http://localhost/" 2>/dev/null || echo "failed")
    if echo "$API_TEST" | grep -q "Staticman"; then
        echo "✅ Staticman API is responding!"
    else
        echo "⚠️  Staticman API test failed"
    fi
fi

echo ""
echo "🎉 Deployment complete!"
echo ""
echo "💡 Usage:"
echo "  ./scripts/deploy.sh           # Deploy with existing image"
echo "  ./scripts/deploy.sh --rebuild  # Force rebuild image"
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

if [ "$FORCE_REBUILD" = true ] || [ "$DOCKERFILE_CHANGED" = true ]; then
    echo ""
    echo "🧹 Cleaning up old images..."
    docker image prune -f >/dev/null 2>&1
    echo "✅ Cleanup complete"
fi
