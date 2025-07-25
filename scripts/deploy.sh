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

echo "🔐 Creating/updating Docker secrets..."
# Remove old secrets if they exist and create new ones
docker secret rm github_token 2>/dev/null || true
docker secret rm rsa_private_key 2>/dev/null || true

echo "$GITHUB_TOKEN" | docker secret create github_token -
echo "$RSA_PRIVATE_KEY" | docker secret create rsa_private_key -

echo "✅ Secrets created"

# Remove existing stack
if docker stack ls --format "table {{.Name}}" | grep -q "^${STACK_NAME}$"; then
    echo "🛑 Removing existing stack..."
    docker stack rm $STACK_NAME
    sleep 15
fi

echo "🏗️  Building Staticman image..."
docker build -t staticman:latest .

echo "⚙️  Creating nginx config..."
CONFIG_NAME="nginx_config_$TIMESTAMP"
docker config create $CONFIG_NAME configs/nginx.conf

echo "📝 Preparing deployment configuration..."
sed "s/nginx_config/$CONFIG_NAME/g" docker-compose.swarm.yml > docker-compose.swarm.tmp.yml

echo "🚀 Deploying Staticman stack with secrets: $STACK_NAME"
docker stack deploy -c docker-compose.swarm.tmp.yml $STACK_NAME

rm docker-compose.swarm.tmp.yml

echo "⏳ Waiting for services to start..."
sleep 20

# Monitor deployment
for i in {1..12}; do
    echo "🔍 Checking deployment status ($i/12)..."
    docker stack services $STACK_NAME
    
    STATICMAN_RUNNING=$(docker service ls --filter name=${STACK_NAME}_staticman --format "table {{.Replicas}}" | grep -v REPLICAS | grep -c "1/1" || echo "0")
    
    if [ "$STATICMAN_RUNNING" = "1" ]; then
        echo "✅ Staticman service is running!"
        break
    else
        echo "⏳ Staticman still starting... checking logs:"
        docker service logs ${STACK_NAME}_staticman --tail 3
    fi
    
    sleep 10
done

echo ""
echo "📊 Final status:"
docker stack services $STACK_NAME

# Clean up old configs
echo "🧹 Cleaning up old configs..."
docker config ls --format "table {{.Name}}" | grep "nginx_config_" | sort | head -n -3 | xargs -r docker config rm 2>/dev/null || true
