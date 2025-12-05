═══════════════════════════════════════════════════════════
🎴 CARD GAME - VOLLEDIGE INSTALLATIE INSTRUCTIES
═══════════════════════════════════════════════════════════

INHOUD:
1. Voorbereiding (30 min)
2. Repository Setup (10 min)
3. OpenStack Credentials (10 min)
4. Deployment (15 min)
5. Verificatie (10 min)
6. Troubleshooting

═══════════════════════════════════════════════════════════
STAP 1: VOORBEREIDING
═══════════════════════════════════════════════════════════

1.1 Installeer tools op je lokale machine:

# macOS:
brew install terraform ansible python-openstackclient

# Ubuntu 22.04:
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform ansible python3-openstackclient

# Windows:
choco install terraform ansible python-openstackclient

1.2 Verificatie:
terraform --version
ansible --version
openstack --version

═══════════════════════════════════════════════════════════
STAP 2: REPOSITORY SETUP
═══════════════════════════════════════════════════════════

2.1 Clone deze repository:
git clone <jouw-repo-url>
cd card-game-infrastructure

2.2 Maak executable scripts:
chmod +x scripts/*.sh

═══════════════════════════════════════════════════════════
STAP 3: OPENSTACK CREDENTIALS SETUP
═══════════════════════════════════════════════════════════

3.1 Log in op Cyso Cloud:
https://cyso.cloud

3.2 Download clouds.yaml:
- Navigeer naar: API Access
- Download: clouds.yaml
- Plaats in: ~/.config/openstack/clouds.yaml

mkdir -p ~/.config/openstack
mv ~/Downloads/clouds.yaml ~/.config/openstack/

3.3 Test verbinding:
openstack --os-cloud fuga server list

3.4 Maak SSH key:
ssh-keygen -t ed25519 -f ~/.ssh/card-game-key -C "card-game"

3.5 Upload SSH key naar OpenStack:
openstack --os-cloud fuga keypair create --public-key ~/.ssh/card-game-key.pub card-game-key

3.6 Verificeer:
openstack --os-cloud fuga keypair list

═══════════════════════════════════════════════════════════
STAP 4: CONFIGURATIE
═══════════════════════════════════════════════════════════

4.1 Gather OpenStack informatie:

# Lijst images (kies Ubuntu 22.04):
openstack --os-cloud fuga image list | grep Ubuntu

# Lijst flavors (kies m1.medium of groter):
openstack --os-cloud fuga flavor list

# Lijst networks:
openstack --os-cloud fuga network list

4.2 Edit terraform.tfvars:
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars

Vul in:
cloud_name       = "fuga"
image_name       = "Ubuntu 22.04"
flavor_name      = "m1.medium"
network_name     = "public"
key_pair         = "card-game-key"
domain_name      = "card-game.jouwnaam.nl"
admin_email      = "jouw@email.nl"

═══════════════════════════════════════════════════════════
STAP 5: DEPLOYMENT
═══════════════════════════════════════════════════════════

5.1 Run deployment script:
cd ..
./scripts/deploy.sh

5.2 Of handmatig:
cd terraform
terraform init
terraform plan
terraform apply

5.3 Noteer het IP adres uit de output!

5.4 Wacht 10-15 minuten voor cloud-init...

═══════════════════════════════════════════════════════════
STAP 6: VERIFICATIE
═══════════════════════════════════════════════════════════

6.1 Check service status:
./scripts/status.sh <INSTANCE_IP>

6.2 Test backend:
curl http://<INSTANCE_IP>:5000/api/users

6.3 Test frontend:
Open browser: http://<INSTANCE_IP>

6.4 SSH in server:
ssh -i ~/.ssh/card-game-key ubuntu@<INSTANCE_IP>

6.5 Check logs:
./scripts/logs.sh <INSTANCE_IP>

═══════════════════════════════════════════════════════════
ONDERHOUD
═══════════════════════════════════════════════════════════

# Backup maken:
./scripts/backup.sh <INSTANCE_IP>

# Logs bekijken:
./scripts/logs.sh <INSTANCE_IP>

# Status checken:
./scripts/status.sh <INSTANCE_IP>

# Update applicatie:
./scripts/update.sh <INSTANCE_IP>

# Alles verwijderen:
./scripts/destroy.sh

═══════════════════════════════════════════════════════════
TROUBLESHOOTING
═══════════════════════════════════════════════════════════

PROBLEEM: Backend start niet
OPLOSSING:
  ssh -i ~/.ssh/card-game-key ubuntu@<IP>
  sudo journalctl -u card-game-backend -n 100
  sudo systemctl restart card-game-backend

PROBLEEM: Database connectie error
OPLOSSING:
  sudo -u postgres psql card_game
  SELECT COUNT(*) FROM questions;

PROBLEEM: Port 5000 geblokkeerd
OPLOSSING:
  Check security groups in OpenStack dashboard

PROBLEEM: Nginx 502 Bad Gateway
OPLOSSING:
  curl http://localhost:5000/api/users
  sudo nginx -t
  sudo systemctl restart nginx

═══════════════════════════════════════════════════════════
URLS & TOEGANG
═══════════════════════════════════════════════════════════

Frontend:  http://<INSTANCE_IP>
Backend:   http://<INSTANCE_IP>:5000
SSH:       ssh -i ~/.ssh/card-game-key ubuntu@<INSTANCE_IP>

═══════════════════════════════════════════════════════════
SUPPORT
═══════════════════════════════════════════════════════════

Issues? Check:
1. /var/log/cloud-init-output.log op de server
2. Terraform output voor IP adres
3. OpenStack console voor instance status
4. GitHub Issues voor support

═══════════════════════════════════════════════════════════