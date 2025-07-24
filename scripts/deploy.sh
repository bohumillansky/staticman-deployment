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

echo "Deploying Staticman stack: $STACK_NAME"

# Deploy the stack
docker stack deploy -c docker-compose.swarm.yml $STACK_NAME

echo "Deployment initiated. Checking status..."
sleep 5

# Show stack status
docker stack services $STACK_NAME

echo ""
echo "Deployment complete!"
echo "Access your Staticman instance at: http://$(curl -s ifconfig.me)"
echo ""
echo "Monitor with:"
echo "  docker stack services $STACK_NAME"
echo "  docker service logs ${STACK_NAME}_staticman"
echo "  docker service logs ${STACK_NAME}_nginx"
