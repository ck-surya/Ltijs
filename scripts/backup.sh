#!/bin/bash

# LTI Visual Search Game - Backup Script
# Creates backup of database and logs

set -e

BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "💾 Creating backup in $BACKUP_DIR..."

# Backup MongoDB data
if docker compose ps mongo | grep -q "running"; then
    echo "📊 Backing up MongoDB database..."
    docker compose exec -T mongo mongodump --archive --gzip > "$BACKUP_DIR/mongodb_backup.gz"
else
    echo "⚠️  MongoDB container is not running, skipping database backup"
fi

# Backup logs
if [ -d "logs" ]; then
    echo "📄 Backing up log files..."
    tar -czf "$BACKUP_DIR/logs_backup.tar.gz" logs/
fi

# Backup configuration
echo "⚙️  Backing up configuration..."
cp .env "$BACKUP_DIR/.env.backup" 2>/dev/null || echo "No .env file found"
cp compose.yml "$BACKUP_DIR/"
cp -r traefik "$BACKUP_DIR/"

echo "✅ Backup complete: $BACKUP_DIR"
echo "📦 Backup size: $(du -sh $BACKUP_DIR | cut -f1)"
