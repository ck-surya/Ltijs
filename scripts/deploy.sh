#!/bin/bash

# LTI Visual Search Game - Deployment Script
# This script handles the complete deployment of the application

set -e

echo "🚀 Starting LTI Visual Search Game Deployment..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ .env file not found. Please copy .env.example to .env and configure it."
    exit 1
fi

# Source environment variables
source .env

# Validate required environment variables
required_vars=("LTIJS_KEY" "DB_HOST" "DB_NAME" "LTI_ISSUER" "TRAEFIK_DOMAIN")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Required environment variable $var is not set in .env file"
        exit 1
    fi
done

echo "✅ Environment validation complete"

# Create necessary directories
echo "📁 Creating necessary directories..."
mkdir -p data/db data/traefik logs

# Set proper permissions
chmod 755 data/db data/traefik logs

echo "🏗️  Building and starting services..."

# Stop any existing services
docker compose down --remove-orphans

# Build and start services
docker compose up -d --build

echo "⏳ Waiting for services to be ready..."
sleep 10

# Check service health
if docker compose ps | grep -q "unhealthy\|restarting"; then
    echo "❌ Some services are not healthy. Checking logs..."
    docker compose logs --tail=50
    exit 1
fi

echo "✅ All services are running"

# Display deployment information
echo ""
echo "🎉 Deployment Complete!"
echo "===================="
echo "Application URL: https://$TRAEFIK_DOMAIN"
echo "Traefik Dashboard: https://$TRAEFIK_DOMAIN:8080"
echo ""
echo "To view logs: docker compose logs -f"
echo "To stop: docker compose down"
echo "To restart: docker compose restart"
echo ""
echo "LTI Registration Details:"
echo "- Login URL: https://$TRAEFIK_DOMAIN/login"
echo "- Target URL: https://$TRAEFIK_DOMAIN/"
echo "- JWK Set URL: https://$TRAEFIK_DOMAIN/.well-known/jwks"
echo ""
