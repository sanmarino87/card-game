#!/bin/bash
INSTANCE_IP=$1

if [ -z "$INSTANCE_IP" ]; then
    echo "Usage: ./update.sh <instance_ip>"
    exit 1
fi

echo "🔄 Updating application on $INSTANCE_IP"

ssh -i ~/.ssh/card-game-key ubuntu@$INSTANCE_IP << 'EOF'
cd /home/cardgame/card-game

echo "📥 Pulling latest code..."
git pull origin main

echo "📦 Installing backend dependencies..."
cd backend
npm install

echo "🏗️  Building frontend..."
cd ../frontend
npm install
npm run build

echo "♻️  Restarting services..."
sudo systemctl restart card-game-backend
sudo systemctl restart card-game-frontend

echo "✅ Update complete!"
EOF