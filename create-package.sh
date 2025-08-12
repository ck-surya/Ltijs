#!/bin/bash

# LTI Visual Search Game - Deployment Package Creator
# This script creates a deployment-ready package

set -e

echo "📦 Creating deployment package for LTI Visual Search Game..."

# Define package name with timestamp
PACKAGE_NAME="lti-visual-search-$(date +%Y%m%d_%H%M%S)"
PACKAGE_DIR="/tmp/$PACKAGE_NAME"
ARCHIVE_NAME="${PACKAGE_NAME}.tar.gz"

# Create temporary package directory
mkdir -p "$PACKAGE_DIR"

echo "📂 Copying essential files..."

# Copy essential files and directories
cp -r server/ "$PACKAGE_DIR/"
cp -r public/ "$PACKAGE_DIR/"
cp -r traefik/ "$PACKAGE_DIR/"
cp package.json "$PACKAGE_DIR/"
cp package-lock.json "$PACKAGE_DIR/"
cp Dockerfile "$PACKAGE_DIR/"
cp compose.yml "$PACKAGE_DIR/"
cp .env.example "$PACKAGE_DIR/"
cp .dockerignore "$PACKAGE_DIR/"
cp .gitignore "$PACKAGE_DIR/"

# Create necessary directories in the package
mkdir -p "$PACKAGE_DIR/logs/app"
mkdir -p "$PACKAGE_DIR/logs/traefik"
mkdir -p "$PACKAGE_DIR/logs/mongo"
mkdir -p "$PACKAGE_DIR/data/letsencrypt"

# Create deployment documentation
cat > "$PACKAGE_DIR/DEPLOYMENT.md" << 'EOF'
# LTI Visual Search Game - Deployment Guide

## Quick Start

1. **Upload and extract the package:**
   ```bash
   tar -xzf lti-visual-search-*.tar.gz
   cd lti-visual-search-*
   ```

2. **Configure environment:**
   ```bash
   cp .env.example .env
   # Edit .env with your settings
   nano .env
   ```

3. **Create Docker network:**
   ```bash
   docker network create web
   ```

4. **Deploy with Docker Compose:**
   ```bash
   docker compose up -d --build
   ```

5. **Check status:**
   ```bash
   docker compose ps
   docker compose logs -f app
   ```

## Configuration

### Required .env Variables

- `COOKIE_KEY`: JWT signing key (generate a long random string)
- `MONGO_ROOT_USERNAME`: MongoDB root username
- `MONGO_ROOT_PASSWORD`: MongoDB root password
- `FRAME_ANCESTORS`: Your LMS domain (e.g., 'https://moodle.example.edu')
- `PLATFORMS`: Platform configuration (see .env.example)

### SSL Certificates

The setup uses Traefik with Let's Encrypt for automatic SSL certificates.
Make sure your domain points to your server before deployment.

### LTI Platform Registration

After deployment, register your tool in your LMS with:

- **Login URL:** `https://your-domain.com/login`
- **Target URL:** `https://your-domain.com/`
- **JWK Set URL:** `https://your-domain.com/.well-known/jwks`

## Monitoring

- **Application logs:** `docker compose logs app`
- **Traefik logs:** `docker compose logs traefik`
- **MongoDB logs:** `docker compose logs mongo`
- **All logs:** `docker compose logs -f`

## Maintenance

### Updates
```bash
git pull origin main
docker compose build --no-cache
docker compose up -d
```

### Backups
```bash
# Backup database
docker compose exec mongo mongodump --archive --gzip > backup_$(date +%Y%m%d).gz

# Backup logs
tar -czf logs_backup_$(date +%Y%m%d).tar.gz logs/
```

### Scaling
To run multiple instances behind a load balancer:
```bash
docker compose up -d --scale app=3
```

## Troubleshooting

### Common Issues

1. **Port conflicts:** Ensure ports 80, 443, and 8080 are free
2. **SSL issues:** Check domain DNS and firewall settings
3. **MongoDB connection:** Verify credentials and network connectivity
4. **LTI errors:** Check platform configuration and logs

### Debug Mode
Set `NODE_ENV=development` in .env for detailed logging.

### Support
Check logs and documentation. For issues, review the GitHub repository.
EOF

# Create server deployment script
cat > "$PACKAGE_DIR/deploy.sh" << 'EOF'
#!/bin/bash

# Server deployment script
set -e

echo "🚀 Deploying LTI Visual Search Game..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is available
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose is not available. Please install Docker Compose."
    exit 1
fi

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ .env file not found. Please copy .env.example to .env and configure it."
    echo "   cp .env.example .env"
    echo "   nano .env"
    exit 1
fi

# Load environment variables
source .env

# Validate required variables
required_vars=("COOKIE_KEY" "MONGO_ROOT_USERNAME" "MONGO_ROOT_PASSWORD")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Required environment variable $var is not set in .env file"
        exit 1
    fi
done

echo "✅ Environment validation complete"

# Create Docker network if it doesn't exist
if ! docker network ls | grep -q "web"; then
    echo "🌐 Creating Docker network 'web'..."
    docker network create web
fi

# Create necessary directories
mkdir -p logs/{app,traefik,mongo} data/letsencrypt

# Set proper permissions
chmod 755 logs data
chmod -R 755 logs/*

echo "🏗️  Building and starting services..."

# Stop any existing services
docker compose down --remove-orphans

# Build and start services
docker compose up -d --build

echo "⏳ Waiting for services to be ready..."
sleep 15

# Check service health
echo "🔍 Checking service status..."
docker compose ps

if docker compose ps | grep -q "unhealthy\|restarting"; then
    echo "⚠️  Some services may have issues. Checking logs..."
    docker compose logs --tail=50
fi

echo ""
echo "🎉 Deployment Complete!"
echo "===================="
echo ""
echo "📊 Service Status:"
docker compose ps --format "table {{.Name}}\t{{.State}}\t{{.Status}}"
echo ""
echo "🌐 Access URLs:"
echo "- Application: https://$(hostname -f) (or your configured domain)"
echo "- Traefik Dashboard: http://$(hostname -f):8080"
echo ""
echo "📝 Useful Commands:"
echo "- View logs: docker compose logs -f"
echo "- Stop services: docker compose down"
echo "- Restart: docker compose restart"
echo "- Update: docker compose pull && docker compose up -d"
echo ""
echo "🔧 LTI Registration URLs:"
echo "- Login URL: https://$(hostname -f)/login"
echo "- Target URL: https://$(hostname -f)/"
echo "- JWK Set URL: https://$(hostname -f)/.well-known/jwks"
echo ""
EOF

chmod +x "$PACKAGE_DIR/deploy.sh"

# Create a simple backup script
cat > "$PACKAGE_DIR/backup.sh" << 'EOF'
#!/bin/bash

# Simple backup script
BACKUP_DIR="backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "💾 Creating backup..."

# Backup database
if docker compose ps mongo | grep -q "running"; then
    docker compose exec -T mongo mongodump --archive --gzip > "$BACKUP_DIR/database.gz"
    echo "✅ Database backed up"
fi

# Backup logs
if [ -d "logs" ]; then
    tar -czf "$BACKUP_DIR/logs.tar.gz" logs/
    echo "✅ Logs backed up"
fi

# Backup configuration
cp .env "$BACKUP_DIR/.env.backup" 2>/dev/null || true

echo "✅ Backup complete: $BACKUP_DIR"
EOF

chmod +x "$PACKAGE_DIR/backup.sh"

echo "🗜️  Creating archive..."

# Create the archive
cd /tmp
tar -czf "$ARCHIVE_NAME" "$PACKAGE_NAME"

# Move to current directory
mv "$ARCHIVE_NAME" "$OLDPWD/"

# Cleanup
rm -rf "$PACKAGE_DIR"

echo ""
echo "✅ Deployment package created successfully!"
echo "📦 Package: $ARCHIVE_NAME"
echo "📏 Size: $(du -sh "$ARCHIVE_NAME" | cut -f1)"
echo ""
echo "🚀 To deploy on your server:"
echo "1. Upload: scp $ARCHIVE_NAME user@your-server:/path/to/deployment/"
echo "2. Extract: tar -xzf $ARCHIVE_NAME"
echo "3. Configure: cd lti-visual-search-* && cp .env.example .env && nano .env"
echo "4. Deploy: ./deploy.sh"
echo ""
