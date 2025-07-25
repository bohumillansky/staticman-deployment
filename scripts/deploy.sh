#!/bin/bash

set -e

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found. Run ./scripts/setup.sh first."
    exit 1
fi

STACK_NAME=${STACK_NAME:-staticman}
TIMESTAMP=$(date +%s)

echo "🔍 Checking if stack exists..."
if docker stack ls --format "table {{.Name}}" | grep -q "^${STACK_NAME}$"; then
    echo "📋 Stack '$STACK_NAME' exists. Performing rolling update..."
    UPDATE_MODE="update"
else
    echo "🆕 Stack '$STACK_NAME' not found. Performing initial deployment..."
    UPDATE_MODE="initial"
fi

echo "🏗️  Building Staticman image..."
# Use timestamp to force rebuild and detect image changes
IMAGE_TAG="staticman:$TIMESTAMP"
docker build -t $IMAGE_TAG .
docker tag $IMAGE_TAG staticman:latest

echo "⚙️  Updating configurations..."

# Handle nginx config changes with versioning (fixes the "in use" error)
CONFIG_NAME="nginx_config_$TIMESTAMP"
echo "📝 Creating new nginx config: $CONFIG_NAME"
docker config create $CONFIG_NAME configs/nginx.conf

echo "📝 Updating docker-compose file to use new config..."
# Create temporary compose file with new config name
sed "s/nginx_config/$CONFIG_NAME/g" docker-compose.swarm.yml > docker-compose.swarm.tmp.yml

echo "🚀 Deploying Staticman stack: $STACK_NAME"
echo "📄 Using compose file: docker-compose.swarm.tmp.yml"

# Deploy the stack (this handles ALL changes in docker-compose.swarm.yml)
docker stack deploy -c docker-compose.swarm.tmp.yml $STACK_NAME

# Clean up temporary file
rm docker-compose.swarm.tmp.yml

if [ "$UPDATE_MODE" = "update" ]; then
    echo "🔄 Docker Swarm will automatically detect and apply changes to:"
    echo "   • Service definitions (replicas, resources, etc.)"
    echo "   • Network configurations"
    echo "   • Volume mounts"
    echo "   • Environment variables"
    echo "   • Port mappings"
    echo "   • Health checks"
    echo "   • Deployment strategies"
fi

echo "⏳ Monitoring deployment progress..."

# Wait for deployment to complete
for i in {1..24}; do  # Increased timeout for complex updates
    sleep 5
    echo "🔍 Checking deployment status ($i/24)..."
    
    # Get service status
    SERVICES_STATUS=$(docker stack services $STACK_NAME --format "table {{.Name}}\t{{.Replicas}}" 2>/dev/null || echo "")
    
    if [ -n "$SERVICES_STATUS" ]; then
        echo "$SERVICES_STATUS"
        
        # Check if all services are running
        RUNNING=$(echo "$SERVICES_STATUS" | grep -v NAME | grep -c "1/1" || true)
        TOTAL=$(echo "$SERVICES_STATUS" | grep -v NAME | wc -l)
        
        if [ "$RUNNING" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
            echo "✅ All services are running successfully!"
            break
        fi
    fi
    
    if [ $i -eq 24 ]; then
        echo "⚠️  Deployment taking longer than expected."
        echo "🔍 Check logs for issues:"
        echo "  docker service logs ${STACK_NAME}_staticman --tail 20"
        echo "  docker service logs ${STACK_NAME}_nginx --tail 20"
        echo ""
        echo "🔍 Check service details:"
        echo "  docker service ps ${STACK_NAME}_staticman --no-trunc"
        echo "  docker service ps ${STACK_NAME}_nginx --no-trunc"
    fi
done

# Show final status
echo ""
echo "📊 Final deployment status:"
docker stack services $STACK_NAME

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
echo "  docker stack services $STACK_NAME"
echo "  docker service logs ${STACK_NAME}_staticman --follow"
echo "  docker service logs ${STACK_NAME}_nginx --follow"
echo ""
echo "🔧 Manage services:"
echo "  docker service scale ${STACK_NAME}_staticman=2  # Scale up"
echo "  docker service update --force ${STACK_NAME}_staticman  # Force restart"
echo "  docker stack rm $STACK_NAME  # Remove stack"

# Clean up old images (keep last 3)
echo ""
echo "🧹 Cleaning up old images..."
OLD_IMAGES=$(docker images staticman --format "table {{.Repository}}:{{.Tag}}" | grep -E "staticman:[0-9]+" | tail -n +4 || true)
if [ -n "$OLD_IMAGES" ]; then
    echo "$OLD_IMAGES" | xargs docker rmi 2>/dev/null || echo "Some images may still be in use"
    echo "✅ Cleanup complete"
else
    echo "ℹ️  No old images to clean"
fi

# Clean up old configs (keep last 3)
echo "🧹 Cleaning up old nginx configs..."
OLD_CONFIGS=$(docker config ls --format "table {{.Name}}" | grep "nginx_config_" | sort | head -n -3 || true)
if [ -n "$OLD_CONFIGS" ]; then
    echo "$OLD_CONFIGS" | xargs docker config rm 2>/dev/null || echo "Some configs may still be in use"
    echo "✅ Config cleanup complete"
else
    echo "ℹ️  No old configs to clean"
fi
