#!/bin/bash
INSTANCE_IP=$1

if [ -z "$INSTANCE_IP" ]; then
    echo "Usage: ./logs.sh <instance_ip>"
    exit 1
fi

echo "📋 Viewing logs from $INSTANCE_IP"
echo "Choose log to view:"
echo "1) Cloud-init"
echo "2) Backend"
echo "3) Frontend"
echo "4) Nginx"
echo "5) PostgreSQL"

read -p "Enter choice: " choice

case $choice in
    1) ssh -i ~/.ssh/card-game-key ubuntu@$INSTANCE_IP "sudo tail -f /var/log/cloud-init-output.log" ;;
    2) ssh -i ~/.ssh/card-game-key ubuntu@$INSTANCE_IP "sudo journalctl -u card-game-backend -f" ;;
    3) ssh -i ~/.ssh/card-game-key ubuntu@$INSTANCE_IP "sudo journalctl -u card-game-frontend -f" ;;
    4) ssh -i ~/.ssh/card-game-key ubuntu@$INSTANCE_IP "sudo tail -f /var/log/nginx/error.log" ;;
    5) ssh -i ~/.ssh/card-game-key ubuntu@$INSTANCE_IP "sudo journalctl -u postgresql -f" ;;
    *) echo "Invalid choice" ;;
esac