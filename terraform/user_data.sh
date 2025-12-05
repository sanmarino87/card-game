#!/bin/bash
# ============================================
# terraform/user_data.sh
# ============================================

set -e

echo "=== Card Game Cloud-Init Start ===" | tee -a /var/log/card-game-init.log

# Update system
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install basic dependencies
apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    python3 \
    python3-pip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Install Node.js 18.x
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Install PostgreSQL
apt-get install -y postgresql postgresql-contrib

# Install Nginx
apt-get install -y nginx

# Install Certbot (SSL)
apt-get install -y certbot python3-certbot-nginx

# Install Ansible
apt-add-repository --yes --update ppa:ansible/ansible
apt-get install -y ansible

# Create app user
useradd -m -s /bin/bash cardgame

# Clone app repositories
cd /opt
git clone https://github.com/sanmarino87/card-game || echo "App repo not found"

# Create Ansible files locally
mkdir -p /opt/ansible
cd /opt/ansible

cat > ansible.cfg << 'ANSIBLECFG'
[defaults]
inventory = hosts.ini
host_key_checking = False
roles_path = roles
ANSIBLECFG

cat > hosts.ini << 'HOSTS'
[local]
localhost ansible_connection=local
HOSTS

cat > group_vars_all.yml << 'GROUPVARS'
---
db_password: "${db_password}"
domain_name: "${domain_name}"
admin_email: "${admin_email}"
app_user: cardgame
app_home: /home/cardgame
postgres_db: card_game
postgres_user: cardgame
GROUPVARS

# Create main playbook
cat > site.yml << 'PLAYBOOK'
---
- name: Deploy Card Game Application
  hosts: local
  become: yes
  vars_files:
    - group_vars_all.yml
  
  tasks:
    - name: Setup PostgreSQL
      import_tasks: tasks/postgres.yml
    
    - name: Setup Application
      import_tasks: tasks/app.yml
    
    - name: Setup Nginx
      import_tasks: tasks/nginx.yml
    
    - name: Verify services
      import_tasks: tasks/verify.yml
PLAYBOOK

# Create task files
mkdir -p tasks

cat > tasks/postgres.yml << 'POSTGRES'
---
- name: Ensure PostgreSQL is running
  systemd:
    name: postgresql
    state: started
    enabled: yes

- name: Install psycopg2
  apt:
    name: python3-psycopg2
    state: present

- name: Create PostgreSQL user
  become_user: postgres
  postgresql_user:
    name: "{{ postgres_user }}"
    password: "{{ db_password }}"
    role_attr_flags: CREATEDB

- name: Create PostgreSQL database
  become_user: postgres
  postgresql_db:
    name: "{{ postgres_db }}"
    owner: "{{ postgres_user }}"
    encoding: UTF8

- name: Initialize database schema
  become_user: postgres
  postgresql_query:
    db: "{{ postgres_db }}"
    query: |
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) UNIQUE NOT NULL,
        total_games INT DEFAULT 0,
        wins INT DEFAULT 0,
        losses INT DEFAULT 0,
        total_points INT DEFAULT 0,
        is_admin BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
      
      CREATE TABLE IF NOT EXISTS questions (
        id SERIAL PRIMARY KEY,
        difficulty INT NOT NULL,
        text TEXT NOT NULL,
        points INT NOT NULL,
        is_deleted BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
      
      CREATE TABLE IF NOT EXISTS games (
        id SERIAL PRIMARY KEY,
        point_limit INT NOT NULL,
        status VARCHAR(50) DEFAULT 'active',
        current_player_turn INT,
        current_round INT DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
      
      CREATE TABLE IF NOT EXISTS cards (
        id SERIAL PRIMARY KEY,
        game_id INT NOT NULL,
        question_1_id INT NOT NULL,
        question_2_id INT NOT NULL,
        question_3_id INT NOT NULL,
        used BOOLEAN DEFAULT FALSE,
        FOREIGN KEY (game_id) REFERENCES games(id),
        FOREIGN KEY (question_1_id) REFERENCES questions(id),
        FOREIGN KEY (question_2_id) REFERENCES questions(id),
        FOREIGN KEY (question_3_id) REFERENCES questions(id)
      );
      
      CREATE TABLE IF NOT EXISTS game_players (
        id SERIAL PRIMARY KEY,
        game_id INT NOT NULL,
        user_id INT NOT NULL,
        player_order INT NOT NULL,
        current_score INT DEFAULT 0,
        finished BOOLEAN DEFAULT FALSE,
        FOREIGN KEY (game_id) REFERENCES games(id),
        FOREIGN KEY (user_id) REFERENCES users(id)
      );
      
      CREATE TABLE IF NOT EXISTS game_history (
        id SERIAL PRIMARY KEY,
        game_id INT NOT NULL,
        user_id INT NOT NULL,
        card_id INT NOT NULL,
        question_chosen INT NOT NULL,
        points_earned INT NOT NULL,
        action_type VARCHAR(50),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (game_id) REFERENCES games(id),
        FOREIGN KEY (user_id) REFERENCES users(id),
        FOREIGN KEY (card_id) REFERENCES cards(id)
      );
      
      CREATE TABLE IF NOT EXISTS suspended_games (
        id SERIAL PRIMARY KEY,
        game_id INT NOT NULL UNIQUE,
        game_data JSONB,
        expires_at TIMESTAMP DEFAULT (CURRENT_TIMESTAMP + INTERVAL '2 weeks'),
        FOREIGN KEY (game_id) REFERENCES games(id)
      );
POSTGRES

cat > tasks/app.yml << 'APP'
---
- name: Clone application if not exists
  git:
    repo: https://github.com/yourusername/card-game-app.git
    dest: "{{ app_home }}/card-game"
    version: main
  become_user: "{{ app_user }}"
  ignore_errors: yes

- name: Create backend directory
  file:
    path: "{{ app_home }}/card-game/backend"
    state: directory
    owner: "{{ app_user }}"
    group: "{{ app_user }}"

- name: Create backend files
  copy:
    dest: "{{ app_home }}/card-game/backend/{{ item.name }}"
    content: "{{ item.content }}"
    owner: "{{ app_user }}"
    group: "{{ app_user }}"
  loop:
    - name: package.json
      content: |
        {
          "name": "card-game-backend",
          "version": "1.0.0",
          "main": "server.js",
          "scripts": {
            "start": "node server.js",
            "dev": "nodemon server.js"
          },
          "dependencies": {
            "express": "^4.18.2",
            "pg": "^8.11.0",
            "cors": "^2.8.5",
            "dotenv": "^16.0.3"
          }
        }
    - name: .env
      content: |
        NODE_ENV=production
        PORT=5000
        DB_USER={{ postgres_user }}
        DB_PASSWORD={{ db_password }}
        DB_HOST=localhost
        DB_PORT=5432
        DB_NAME={{ postgres_db }}
        CORS_ORIGIN=*

- name: Install backend dependencies
  npm:
    path: "{{ app_home }}/card-game/backend"
    state: present
  become_user: "{{ app_user }}"

- name: Create systemd service for backend
  copy:
    dest: /etc/systemd/system/card-game-backend.service
    content: |
      [Unit]
      Description=Card Game Backend
      After=network.target postgresql.service
      
      [Service]
      Type=simple
      User={{ app_user }}
      WorkingDirectory={{ app_home }}/card-game/backend
      ExecStart=/usr/bin/node server.js
      Restart=always
      RestartSec=10
      StandardOutput=journal
      StandardError=journal
      
      [Install]
      WantedBy=multi-user.target

- name: Reload systemd
  systemd:
    daemon_reload: yes

- name: Start backend service
  systemd:
    name: card-game-backend
    enabled: yes
    state: started
APP

cat > tasks/nginx.yml << 'NGINX'
---
- name: Remove default Nginx config
  file:
    path: /etc/nginx/sites-enabled/default
    state: absent

- name: Create Nginx config
  copy:
    dest: /etc/nginx/sites-available/card-game
    content: |
      upstream backend {
          server localhost:5000;
      }
      
      server {
          listen 80;
          server_name _;
          
          location /api {
              proxy_pass http://backend;
              proxy_http_version 1.1;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection 'upgrade';
              proxy_set_header Host $host;
              proxy_cache_bypass $http_upgrade;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          }
          
          location / {
              root /var/www/card-game;
              try_files $uri $uri/ /index.html;
          }
      }

- name: Enable Nginx site
  file:
    src: /etc/nginx/sites-available/card-game
    dest: /etc/nginx/sites-enabled/card-game
    state: link

- name: Test Nginx config
  command: nginx -t

- name: Restart Nginx
  systemd:
    name: nginx
    state: restarted
    enabled: yes
NGINX

cat > tasks/verify.yml << 'VERIFY'
---
- name: Check PostgreSQL
  command: systemctl is-active postgresql
  register: pg_status
  failed_when: pg_status.stdout != "active"

- name: Check backend
  command: systemctl is-active card-game-backend
  register: backend_status
  failed_when: backend_status.stdout != "active"

- name: Check Nginx
  command: systemctl is-active nginx
  register: nginx_status
  failed_when: nginx_status.stdout != "active"

- name: Print success message
  debug:
    msg:
      - "========================================="
      - "Card Game Deployment Successful!"
      - "========================================="
      - "Backend: http://localhost:5000"
      - "Frontend: http://localhost"
      - "========================================="
VERIFY

# Run Ansible playbook
echo "Running Ansible playbook..." | tee -a /var/log/card-game-init.log
ansible-playbook site.yml -vv | tee -a /var/log/card-game-init.log

echo "=== Cloud-Init Complete ===" | tee -a /var/log/card-game-init.log