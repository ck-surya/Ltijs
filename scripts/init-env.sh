#!/bin/bash

# LTI Visual Search Game - Environment Initialization Script
# This script automatically configures database settings based on deployment type

set -e

echo "🔧 Initializing environment configuration..."

# Check if .env file exists
if [ ! -f .env ]; then
    echo "📋 Creating .env file from template..."
    cp .env.example .env
fi

# Function to update or add environment variable
update_env_var() {
    local var_name=$1
    local var_value=$2
    local env_file=${3:-.env}
    
    if grep -q "^${var_name}=" "$env_file"; then
        # Variable exists, update it
        sed -i "s|^${var_name}=.*|${var_name}=${var_value}|" "$env_file"
        echo "✅ Updated ${var_name}"
    else
        # Variable doesn't exist, add it
        echo "${var_name}=${var_value}" >> "$env_file"
        echo "✅ Added ${var_name}"
    fi
}

# Function to detect deployment type
detect_deployment_type() {
    if [ -f "compose.yml" ] || [ -f "docker-compose.yml" ]; then
        echo "docker"
    elif command -v node &> /dev/null && [ -f "package.json" ]; then
        echo "local"
    else
        echo "unknown"
    fi
}

# Detect deployment type
DEPLOYMENT_TYPE=$(detect_deployment_type)
echo "🔍 Detected deployment type: $DEPLOYMENT_TYPE"

case $DEPLOYMENT_TYPE in
    "docker")
        echo "🐳 Configuring for Docker Compose deployment..."
        
        # Set database host to Docker service name
        update_env_var "DB_HOST" "mongo"
        update_env_var "DB_NAME" "lti"
        
        # Ensure MongoDB database name is consistent
        if ! grep -q "^MONGO_DB_NAME=" .env; then
            update_env_var "MONGO_DB_NAME" "lti"
        fi
        
        # Set default production values if not set
        if ! grep -q "^NODE_ENV=" .env || grep -q "^NODE_ENV=development" .env; then
            update_env_var "NODE_ENV" "production"
        fi
        
        echo "✅ Docker Compose configuration complete"
        echo "   - Database Host: mongo (Docker service)"
        echo "   - Database Name: lti"
        echo "   - Environment: production"
        ;;
        
    "local")
        echo "💻 Configuring for local development..."
        
        # Set database host to localhost
        update_env_var "DB_HOST" "localhost"
        update_env_var "DB_NAME" "lti"
        update_env_var "NODE_ENV" "development"
        
        echo "✅ Local development configuration complete"
        echo "   - Database Host: localhost"
        echo "   - Database Name: lti"
        echo "   - Environment: development"
        ;;
        
    "unknown")
        echo "❓ Unknown deployment type. Setting default values..."
        update_env_var "DB_HOST" "localhost"
        update_env_var "DB_NAME" "lti"
        ;;
esac

# Validate critical environment variables
echo ""
echo "🔍 Validating environment configuration..."

# Check for required variables
required_vars=("COOKIE_KEY" "MONGO_ROOT_USERNAME" "MONGO_ROOT_PASSWORD")
missing_vars=()

for var in "${required_vars[@]}"; do
    if ! grep -q "^${var}=" .env || grep -q "^${var}=$" .env || grep -q "^${var}=your-" .env; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -gt 0 ]; then
    echo ""
    echo "⚠️  Warning: The following variables need to be configured:"
    for var in "${missing_vars[@]}"; do
        echo "   - $var"
    done
    echo ""
    echo "Please edit .env file and set proper values for these variables."
    echo "Example values:"
    echo "   COOKIE_KEY=your-very-long-random-secret-key-here"
    echo "   MONGO_ROOT_USERNAME=admin"
    echo "   MONGO_ROOT_PASSWORD=your-secure-password"
fi

# Generate database connection string preview
if grep -q "^DB_HOST=" .env && grep -q "^MONGO_ROOT_USERNAME=" .env; then
    DB_HOST=$(grep "^DB_HOST=" .env | cut -d'=' -f2)
    DB_NAME=$(grep "^DB_NAME=" .env | cut -d'=' -f2)
    MONGO_USER=$(grep "^MONGO_ROOT_USERNAME=" .env | cut -d'=' -f2)
    
    echo ""
    echo "📊 Database Configuration Preview:"
    echo "   Host: $DB_HOST"
    echo "   Database: $DB_NAME"
    echo "   Username: $MONGO_USER"
    echo "   Connection: mongodb://$MONGO_USER:***@$DB_HOST:27017/$DB_NAME"
fi

echo ""
echo "✅ Environment initialization complete!"
echo ""
echo "Next steps:"
echo "1. Review and edit .env file if needed: nano .env"
echo "2. For Docker deployment: ./scripts/deploy.sh"
echo "3. For local development: npm install && npm start"
