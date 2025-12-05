#!/bin/bash
set -e

echo "🗑️  Destroying Card Game Infrastructure..."

cd "$(dirname "$0")/../terraform"

echo "⚠️  This will DELETE everything!"
read -p "Are you sure? (type 'yes' to confirm): " confirmation

if [ "$confirmation" = "yes" ]; then
    terraform destroy
    echo "✅ Infrastructure destroyed"
else
    echo "❌ Cancelled"
    exit 1
fi