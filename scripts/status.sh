#!/bin/bash
INSTANCE_IP=$1

if [ -z "$INSTANCE_IP" ]; then
    echo "Usage: ./status.sh <instance_ip>"
    exit 1
fi

echo "🔍 Checking service status on $INSTANCE_IP"

ssh -i ~/.ssh/card-game-key ubuntu@$INSTANCE_IP << 'EOF'
echo "=== Service Status ==="
sudo systemctl status card-game-backend --no-pager | grep Active
sudo systemctl status card-game-frontend --no-pager | grep Active
sudo systemctl status nginx --no-pager | grep Active
sudo systemctl status postgresql --no-pager | grep Active

echo ""
echo "=== Database ==="
sudo -u postgres psql -c "SELECT COUNT(*) as question_count FROM questions;" card_game

echo ""
echo "=== Disk Usage ==="
df -h | grep -E '(Filesystem|/$)'

echo ""
echo "=== Memory Usage ==="
free -h
EOF