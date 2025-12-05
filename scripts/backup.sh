#!/bin/bash
set -e

INSTANCE_IP=$1

if [ -z "$INSTANCE_IP" ]; then
    echo "Usage: ./backup.sh <instance_ip>"
    exit 1
fi

BACKUP_FILE="card_game_backup_$(date +%Y%m%d_%H%M%S).sql"

echo "📦 Creating database backup..."

ssh -i ~/.ssh/card-game-key ubuntu@$INSTANCE_IP \
    "sudo -u postgres pg_dump card_game" > "$BACKUP_FILE"

echo "✅ Backup saved to: $BACKUP_FILE"