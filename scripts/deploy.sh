set -e

echo "🚀 Starting Card Game Deployment..."

# Check prerequisites
command -v terraform >/dev/null 2>&1 || { echo "❌ Terraform not installed"; exit 1; }
command -v openstack >/dev/null 2>&1 || { echo "❌ OpenStack CLI not installed"; exit 1; }

# Navigate to terraform directory
cd "$(dirname "$0")/../terraform"

echo "📋 Initializing Terraform..."
terraform init

echo "📝 Planning deployment..."
terraform plan -out=tfplan

echo "🔨 Applying infrastructure..."
terraform apply tfplan

echo "⏳ Waiting for cloud-init to complete (this takes ~10 minutes)..."
INSTANCE_IP=$(terraform output -raw instance_ip)

echo "✅ Instance created at: $INSTANCE_IP"
echo "📊 Check deployment status:"
echo "   ssh -i ~/.ssh/card-game-key ubuntu@$INSTANCE_IP 'sudo tail -f /var/log/cloud-init-output.log'"
echo ""
echo "🌐 Application will be available at:"
echo "   http://$INSTANCE_IP"
echo ""
echo "🎮 Deployment complete! Wait 10 minutes for services to start."