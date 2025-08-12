#!/bin/bash

# LTI Visual Search Game - Development Script
# Quick setup for local development

set -e

echo "🛠️  Starting Development Environment..."

# Check if node and npm are installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js first."
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed. Please install npm first."
    exit 1
fi

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Check if .env file exists
if [ ! -f .env ]; then
    echo "📋 Creating .env file from template..."
    cp .env.example .env
    echo "⚠️  Please edit .env file with your configuration before running the application"
fi

# Start MongoDB container for development
echo "🗄️  Starting MongoDB container..."
docker run -d \
    --name lti-mongo-dev \
    --restart unless-stopped \
    -p 27017:27017 \
    -v lti-mongo-data:/data/db \
    mongo:7.0

echo "⏳ Waiting for MongoDB to be ready..."
sleep 5

# Create logs directory
mkdir -p logs

echo "🚀 Starting development server..."
echo "Application will be available at: http://localhost:3000"
echo ""
echo "To stop MongoDB: docker stop lti-mongo-dev"
echo "To remove MongoDB: docker rm lti-mongo-dev"
echo ""

# Start the application
npm start
