#!/bin/bash
# ============================================
# terraform/user_data.sh - FULL NPM BUILD VERSION
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

# Verify Node installation
node --version
npm --version

# Install PostgreSQL
apt-get install -y postgresql postgresql-contrib python3-psycopg2

# Install Nginx
apt-get install -y nginx

# Install Certbot (SSL)
apt-get install -y certbot python3-certbot-nginx

# Create app user
useradd -m -s /bin/bash cardgame

# Create application directories
mkdir -p /home/cardgame/card-game/backend
mkdir -p /home/cardgame/card-game/frontend
mkdir -p /var/www/card-game
chown -R cardgame:cardgame /home/cardgame
chown -R www-data:www-data /var/www/card-game

echo "=== Setting up PostgreSQL ===" | tee -a /var/log/card-game-init.log

# Start PostgreSQL
systemctl start postgresql
systemctl enable postgresql

# Create database and user
sudo -u postgres psql << EOF
CREATE USER cardgame WITH PASSWORD '${db_password}';
CREATE DATABASE card_game OWNER cardgame;
GRANT ALL PRIVILEGES ON DATABASE card_game TO cardgame;
EOF

# Create tables
sudo -u postgres psql -d card_game << 'EOF'
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

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO cardgame;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO cardgame;
EOF

# Seed initial questions (10 per difficulty for testing)
sudo -u postgres psql -d card_game << 'SEED'
INSERT INTO questions (difficulty, text, points) VALUES
(1, 'Wat is je grootste fantasie?', 1),
(1, 'Ben je ooit betrappt terwijl je iets deed wat je niet moest doen?', 1),
(1, 'Wie vind je het aantrekkelijkst in deze groep?', 1),
(1, 'Heb je ooit voor iemand gelogen om indruk te maken?', 1),
(1, 'Wat zou je doen als niemand het zou weten?', 1),
(1, 'Hoe oud was je bij je eerste kus?', 1),
(1, 'Ben je ooit onverwacht aangetrokken tot iemand?', 1),
(1, 'Wat is je ergste datingervaring?', 1),
(1, 'Heb je ooit gespieed op iemand?', 1),
(1, 'Wat voor kleur ondergoed draag je nu?', 1),
(2, 'Geef de persoon links van je een massage', 3),
(2, 'Flirt 30 seconden intens met iemand aan tafel', 3),
(2, 'Maak oogcontact met iemand zonder te glimlachen voor 1 minuut', 3),
(2, 'Fluister je meest pikante gedachte in iemands oor', 3),
(2, 'Dans één lied op een sensuele manier', 3),
(2, 'Maak het meest verleidelijke gezicht dat je kan', 3),
(2, 'Geef iemand een compliment over hun kont', 3),
(2, 'Zeg iets sensuëels over de persoon rechts van je', 3),
(2, 'Bind iemands ogen dicht met een servet', 3),
(2, 'Voer iemand blind te eten', 3),
(3, 'Zoen de persoon rechts van je op de mond', 5),
(3, 'Zoen iemand voor 10 seconden', 5),
(3, 'Geef iemand een tonguekus', 5),
(3, 'Trek je shirt uit voor een foto', 5),
(3, 'Laat je onderbroek zien aan iemand', 5),
(3, 'Zit op iemands schoot en wieg heen en weer', 5),
(3, 'Maak de wildste geluid die je kan tijdens een moment', 5),
(3, 'Streel je eigen lichaam sensueel terwijl je iemand aankijkt', 5),
(3, 'Zeg je wildste fantasie hardop op', 5),
(3, 'Trek je broek een beetje naar beneden', 5);
SEED

echo "=== Setting up Backend ===" | tee -a /var/log/card-game-init.log

# Clone or create backend files
cd /home/cardgame/card-game

# Create backend package.json
cat > backend/package.json << 'BACKEND_PKG'
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
    "pg": "^8.11.3",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1"
  }
}
BACKEND_PKG

# Create backend .env
cat > backend/.env << BACKEND_ENV
NODE_ENV=production
PORT=5000
DB_USER=cardgame
DB_PASSWORD=${db_password}
DB_HOST=localhost
DB_PORT=5432
DB_NAME=card_game
CORS_ORIGIN=*
BACKEND_ENV

# Create backend server.js (complete from previous artifact)
cat > backend/server.js << 'BACKEND_JS'
require('dotenv').config();
const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');

const app = express();
app.use(cors({ origin: process.env.CORS_ORIGIN || '*' }));
app.use(express.json());

const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT || 5432,
});

pool.query('SELECT NOW()', (err, res) => {
  if (err) {
    console.error('❌ Database connection error:', err);
  } else {
    console.log('✅ Database connected:', res.rows[0].now);
  }
});

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date() });
});

app.post('/api/users', async (req, res) => {
  try {
    const { name } = req.body;
    if (!name) return res.status(400).json({ error: 'Name required' });

    const existing = await pool.query('SELECT * FROM users WHERE name = $1', [name]);
    if (existing.rows.length > 0) {
      return res.json(existing.rows[0]);
    }

    const result = await pool.query(
      'INSERT INTO users (name) VALUES ($1) RETURNING *',
      [name]
    );
    res.json(result.rows[0]);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/api/users/:id', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM users WHERE id = $1', [req.params.id]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'User not found' });
    res.json(result.rows[0]);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/api/games', async (req, res) => {
  try {
    const { point_limit, player_names } = req.body;
    if (!point_limit || !player_names || player_names.length < 2) {
      return res.status(400).json({ error: 'Invalid game setup' });
    }

    const gameResult = await pool.query(
      'INSERT INTO games (point_limit, current_player_turn) VALUES ($1, 0) RETURNING id',
      [point_limit]
    );
    const gameId = gameResult.rows[0].id;

    for (let i = 0; i < player_names.length; i++) {
      let user = await pool.query('SELECT id FROM users WHERE name = $1', [player_names[i]]);
      if (user.rows.length === 0) {
        user = await pool.query('INSERT INTO users (name) VALUES ($1) RETURNING id', [player_names[i]]);
      }
      const userId = user.rows[0].id;

      await pool.query(
        'INSERT INTO game_players (game_id, user_id, player_order) VALUES ($1, $2, $3)',
        [gameId, userId, i]
      );
    }

    for (let i = 0; i < 100; i++) {
      const q1 = await pool.query('SELECT id FROM questions WHERE difficulty = 1 AND is_deleted = FALSE ORDER BY RANDOM() LIMIT 1');
      const q2 = await pool.query('SELECT id FROM questions WHERE difficulty = 2 AND is_deleted = FALSE ORDER BY RANDOM() LIMIT 1');
      const q3 = await pool.query('SELECT id FROM questions WHERE difficulty = 3 AND is_deleted = FALSE ORDER BY RANDOM() LIMIT 1');
      
      if (q1.rows.length && q2.rows.length && q3.rows.length) {
        await pool.query(
          'INSERT INTO cards (game_id, question_1_id, question_2_id, question_3_id) VALUES ($1, $2, $3, $4)',
          [gameId, q1.rows[0].id, q2.rows[0].id, q3.rows[0].id]
        );
      }
    }

    res.json({ game_id: gameId });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/api/games/:id', async (req, res) => {
  try {
    const gameResult = await pool.query('SELECT * FROM games WHERE id = $1', [req.params.id]);
    if (gameResult.rows.length === 0) return res.status(404).json({ error: 'Game not found' });

    const playersResult = await pool.query(
      'SELECT gp.*, u.name FROM game_players gp JOIN users u ON gp.user_id = u.id WHERE gp.game_id = $1 ORDER BY gp.player_order',
      [req.params.id]
    );

    res.json({ game: gameResult.rows[0], players: playersResult.rows });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/api/games/:id/next-card', async (req, res) => {
  try {
    const gameId = req.params.id;
    const game = await pool.query('SELECT * FROM games WHERE id = $1', [gameId]);
    if (game.rows.length === 0) return res.status(404).json({ error: 'Game not found' });

    const players = await pool.query(
      'SELECT gp.*, u.name FROM game_players gp JOIN users u ON gp.user_id = u.id WHERE gp.game_id = $1 ORDER BY gp.player_order',
      [gameId]
    );
    const currentPlayer = players.rows[game.rows[0].current_player_turn];

    let card = await pool.query(
      'SELECT * FROM cards WHERE game_id = $1 AND used = FALSE LIMIT 1',
      [gameId]
    );

    if (card.rows.length === 0) {
      await pool.query('UPDATE cards SET used = FALSE WHERE game_id = $1', [gameId]);
      card = await pool.query('SELECT * FROM cards WHERE game_id = $1 AND used = FALSE LIMIT 1', [gameId]);
    }

    const questions = await pool.query(
      'SELECT id, text, points FROM questions WHERE id IN ($1, $2, $3)',
      [card.rows[0].question_1_id, card.rows[0].question_2_id, card.rows[0].question_3_id]
    );

    res.json({
      card_id: card.rows[0].id,
      current_player: currentPlayer,
      questions: questions.rows
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/api/games/:id/answer', async (req, res) => {
  try {
    const { card_id, question_id, action_type } = req.body;
    const gameId = req.params.id;

    const game = await pool.query('SELECT * FROM games WHERE id = $1', [gameId]);
    const players = await pool.query(
      'SELECT gp.*, u.name FROM game_players gp JOIN users u ON gp.user_id = u.id WHERE gp.game_id = $1 ORDER BY gp.player_order',
      [gameId]
    );
    const currentPlayer = players.rows[game.rows[0].current_player_turn];

    const question = await pool.query('SELECT points FROM questions WHERE id = $1', [question_id]);
    const points = action_type === 'refused' ? -5 : question.rows[0].points;

    await pool.query(
      'UPDATE game_players SET current_score = current_score + $1 WHERE id = $2',
      [points, currentPlayer.id]
    );

    await pool.query(
      'INSERT INTO game_history (game_id, user_id, card_id, question_chosen, points_earned, action_type) VALUES ($1, $2, $3, $4, $5, $6)',
      [gameId, currentPlayer.user_id, card_id, question_id, points, action_type]
    );

    await pool.query('UPDATE cards SET used = TRUE WHERE id = $1', [card_id]);

    const updated = await pool.query('SELECT current_score FROM game_players WHERE id = $1', [currentPlayer.id]);
    const newScore = updated.rows[0].current_score;

    if (newScore >= game.rows[0].point_limit) {
      await pool.query('UPDATE games SET status = $1 WHERE id = $2', ['finished', gameId]);
      
      const finalScores = await pool.query(
        'SELECT gp.*, u.name FROM game_players gp JOIN users u ON gp.user_id = u.id WHERE gp.game_id = $1 ORDER BY gp.current_score DESC',
        [gameId]
      );

      for (const player of finalScores.rows) {
        if (player.current_score >= game.rows[0].point_limit) {
          await pool.query('UPDATE users SET wins = wins + 1, total_games = total_games + 1, total_points = total_points + $1 WHERE id = $2', [player.current_score, player.user_id]);
        } else {
          await pool.query('UPDATE users SET losses = losses + 1, total_games = total_games + 1, total_points = total_points + $1 WHERE id = $2', [player.current_score, player.user_id]);
        }
      }

      return res.json({ game_finished: true, final_scores: finalScores.rows });
    }

    const nextTurn = (game.rows[0].current_player_turn + 1) % players.rows.length;
    await pool.query('UPDATE games SET current_player_turn = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2', [nextTurn, gameId]);

    res.json({ success: true, next_player_turn: nextTurn, new_score: newScore });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/api/admin/questions', async (req, res) => {
  try {
    const { user_id, difficulty, text } = req.body;
    const admin = await pool.query('SELECT is_admin FROM users WHERE id = $1', [user_id]);
    if (!admin.rows[0]?.is_admin) return res.status(403).json({ error: 'Not admin' });

    const points = [1, 3, 5][difficulty - 1];
    const result = await pool.query(
      'INSERT INTO questions (difficulty, text, points) VALUES ($1, $2, $3) RETURNING *',
      [difficulty, text, points]
    );
    res.json(result.rows[0]);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.delete('/api/admin/questions/:id', async (req, res) => {
  try {
    const { user_id } = req.body;
    const admin = await pool.query('SELECT is_admin FROM users WHERE id = $1', [user_id]);
    if (!admin.rows[0]?.is_admin) return res.status(403).json({ error: 'Not admin' });

    await pool.query('UPDATE questions SET is_deleted = TRUE WHERE id = $1', [req.params.id]);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/api/admin/questions', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM questions WHERE is_deleted = FALSE ORDER BY difficulty, id');
    res.json(result.rows);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log('🚀 Backend running on port ' + PORT);
});
BACKEND_JS

chown -R cardgame:cardgame /home/cardgame/card-game/backend
cd /home/cardgame/card-game/backend
sudo -u cardgame npm install

cat > /etc/systemd/system/card-game-backend.service << 'BACKEND_SVC'
[Unit]
Description=Card Game Backend
After=network.target postgresql.service

[Service]
Type=simple
User=cardgame
WorkingDirectory=/home/cardgame/card-game/backend
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
BACKEND_SVC

systemctl daemon-reload
systemctl enable card-game-backend
systemctl start card-game-backend

echo "=== Setting up Frontend (Vue + Vite) ===" | tee -a /var/log/card-game-init.log

cd /home/cardgame/card-game/frontend

# Get the actual IP address (try metadata first, then hostname)
INSTANCE_IP=$(curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || hostname -I | awk '{print $1}')

cat > package.json << 'FRONTEND_PKG'
{
  "name": "card-game-frontend",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "vue": "^3.3.4",
    "axios": "^1.5.1"
  },
  "devDependencies": {
    "@vitejs/plugin-vue": "^4.4.0",
    "vite": "^4.5.0"
  }
}
FRONTEND_PKG

cat > vite.config.js << 'VITE_CONFIG'
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  server: {
    port: 3000,
    host: '0.0.0.0'
  },
  build: {
    outDir: 'dist',
    assetsDir: 'assets'
  }
})
VITE_CONFIG

cat > index.html << 'INDEX_HTML'
<!DOCTYPE html>
<html lang="nl">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>🎴 Kaartspel</title>
</head>
<body>
  <div id="app"></div>
  <script type="module" src="/src/main.js"></script>
</body>
</html>
INDEX_HTML

mkdir -p src/assets

# Use API URL from the artifact you created earlier, but with environment variable
cat > .env.production << ENV_PROD
VITE_API_URL=/api
ENV_PROD

# Create complete frontend files
cat > src/main.js << 'MAIN_JS'
import { createApp } from 'vue'
import App from './App.vue'
import './assets/style.css'

createApp(App).mount('#app')
MAIN_JS

# Create complete App.vue directly (no curl fallback)
cat > src/App.vue << 'APP_VUE'
<template>
  <div class="app">
    <div v-if="!currentUser" class="screen">
      <div class="container">
        <h1>🎴 Kaartspel</h1>
        <p>Erotische Party Game</p>
        <input v-model="nameInput" @keyup.enter="login" placeholder="Voer je naam in..." class="input-field" />
        <button @click="login" class="btn btn-primary">Start Spelen</button>
      </div>
    </div>

    <div v-else-if="screen === 'menu'" class="screen">
      <div class="container">
        <h1>Welkom, {{ currentUser.name }}! 👋</h1>
        <div class="stats-grid">
          <div class="stat-card"><div class="stat-value">{{ currentUser.total_games }}</div><div class="stat-label">Potjes</div></div>
          <div class="stat-card"><div class="stat-value">{{ currentUser.wins }}</div><div class="stat-label">Wins</div></div>
          <div class="stat-card"><div class="stat-value">{{ avgPoints }}</div><div class="stat-label">Avg Punten</div></div>
        </div>
        <button @click="goToGameSetup" class="btn btn-primary">🎮 Nieuw Potje</button>
        <button v-if="currentUser.is_admin" @click="goToAdmin" class="btn btn-secondary">⚙️ Admin Panel</button>
        <button @click="logout" class="btn btn-danger">Uitloggen</button>
      </div>
    </div>

    <div v-else-if="screen === 'setup'" class="screen">
      <div class="container">
        <h2>Game Setup</h2>
        <div class="form-group">
          <label>Puntenlimiet voor winst:</label>
          <input v-model.number="gameSetup.pointLimit" type="number" min="10" class="input-field" />
        </div>
        <div class="form-group">
          <label>Spelers (min. 2):</label>
          <div class="player-list">
            <div v-for="(player, i) in gameSetup.players" :key="i" class="player-item">
              <span>{{ player }}</span>
              <button @click="removePlayer(i)" class="btn-small btn-danger">✕</button>
            </div>
          </div>
          <div class="input-with-button">
            <input v-model="newPlayerName" @keyup.enter="addPlayer" placeholder="Naam van speler..." class="input-field" />
            <button @click="addPlayer" class="btn btn-secondary">Toevoegen</button>
          </div>
        </div>
        <button v-if="gameSetup.players.length >= 2" @click="startGame" class="btn btn-primary btn-large">🚀 Start Potje</button>
        <button @click="backToMenu" class="btn btn-secondary">Terug</button>
      </div>
    </div>

    <div v-else-if="screen === 'gameplay'" class="screen gameplay-screen">
      <div class="container">
        <div class="scoreboard">
          <div v-for="player in gamePlayers" :key="player.id" class="player-score" :class="{ active: player.id === currentGamePlayer.id }">
            <div class="player-name">{{ player.name }}</div>
            <div class="player-points">{{ player.current_score }} pts</div>
          </div>
        </div>
        <div class="turn-indicator"><h2>{{ currentGamePlayer.name }} is aan de beurt</h2></div>
        <div class="card-container">
          <div class="card">
            <div v-for="(q, i) in currentQuestions" :key="q.id" class="question-option" :class="{ selected: selectedQuestion?.id === q.id, easy: i === 0, medium: i === 1, hard: i === 2 }" @click="selectQuestion(q)">
              <div class="difficulty-badge">{{ ['Makkelijk', 'Medium', 'Moeilijk'][i] }}</div>
              <div class="question-text">{{ q.text }}</div>
              <div class="points-badge">+{{ q.points }} punten</div>
            </div>
          </div>
        </div>
        <div v-if="selectedQuestion" class="action-buttons">
          <button @click="answerQuestion('answered')" class="btn btn-success btn-large">✓ Gedaan!</button>
          <button @click="answerQuestion('refused')" class="btn btn-danger">✕ Weigeren (-5 pts)</button>
        </div>
      </div>
    </div>

    <div v-else-if="screen === 'finished'" class="screen">
      <div class="container">
        <h1>🏆 Potje Voorbij!</h1>
        <div class="leaderboard">
          <div v-for="(player, i) in finalScores" :key="player.id" class="leaderboard-item" :class="{ winner: i === 0 }">
            <div class="rank">{{ ['🥇', '🥈', '🥉'][i] || `#$${i + 1}` }}</div>
            <div class="player-info">
              <div class="name">{{ player.name }}</div>
              <div class="score">{{ player.current_score }} punten</div>
            </div>
          </div>
        </div>
        <button @click="playAgain" class="btn btn-primary btn-large">🔄 Speel Opnieuw</button>
        <button @click="backToMenu" class="btn btn-secondary">Terug naar Menu</button>
      </div>
    </div>

    <div v-else-if="screen === 'admin'" class="screen">
      <div class="container">
        <h2>⚙️ Admin Panel</h2>
        <div class="admin-tabs">
          <button @click="adminTab = 'add'" :class="{ active: adminTab === 'add' }" class="btn">Vraag Toevoegen</button>
          <button @click="adminTab = 'manage'" :class="{ active: adminTab === 'manage' }" class="btn">Vragen Beheren</button>
        </div>
        <div v-if="adminTab === 'add'" class="admin-section">
          <h3>Nieuwe Vraag Toevoegen</h3>
          <div class="form-group">
            <label>Moeilijkheid:</label>
            <select v-model.number="newQuestion.difficulty" class="input-field">
              <option value="1">Makkelijk (1 pt)</option>
              <option value="2">Medium (3 pts)</option>
              <option value="3">Moeilijk (5 pts)</option>
            </select>
          </div>
          <div class="form-group">
            <label>Vraag/Opdracht:</label>
            <textarea v-model="newQuestion.text" placeholder="Voer de vraag of opdracht in..." class="input-field textarea" rows="4"></textarea>
          </div>
          <button @click="addQuestion" class="btn btn-primary">➕ Voeg Toe</button>
        </div>
        <div v-if="adminTab === 'manage'" class="admin-section">
          <h3>Alle Vragen ({{ allQuestions.length }})</h3>
          <div class="question-list">
            <div v-for="q in allQuestions" :key="q.id" class="question-item">
              <div class="question-content">
                <span class="difficulty-tag" :class="`diff-$${q.difficulty}`">{{ ['Makkelijk', 'Medium', 'Moeilijk'][q.difficulty - 1] }}</span>
                <span>{{ q.text }}</span>
              </div>
              <button @click="deleteQuestion(q.id)" class="btn-small btn-danger">Verwijder</button>
            </div>
          </div>
        </div>
        <button @click="backToMenu" class="btn btn-secondary">Terug</button>
      </div>
    </div>
  </div>
</template>

<script>
import axios from 'axios';
const API = import.meta.env.VITE_API_URL || '/api';

export default {
  data() {
    return {
      currentUser: null,
      nameInput: '',
      screen: 'menu',
      gameSetup: { pointLimit: 50, players: [] },
      newPlayerName: '',
      currentGameId: null,
      gamePlayers: [],
      currentGamePlayer: null,
      currentQuestions: [],
      currentCardId: null,
      selectedQuestion: null,
      finalScores: [],
      adminTab: 'add',
      allQuestions: [],
      newQuestion: { difficulty: 1, text: '' }
    };
  },
  computed: {
    avgPoints() {
      if (!this.currentUser || this.currentUser.total_games === 0) return 0;
      return Math.round(this.currentUser.total_points / this.currentUser.total_games);
    }
  },
  methods: {
    async login() {
      if (!this.nameInput.trim()) return;
      try {
        const res = await axios.post(`$${API}/users`, { name: this.nameInput.trim() });
        this.currentUser = res.data;
        this.screen = 'menu';
      } catch (e) {
        alert('Login mislukt: ' + e.message);
      }
    },
    logout() { this.currentUser = null; this.nameInput = ''; this.screen = 'menu'; },
    goToGameSetup() { this.gameSetup.players = [this.currentUser.name]; this.newPlayerName = ''; this.screen = 'setup'; },
    addPlayer() { if (this.newPlayerName.trim()) { this.gameSetup.players.push(this.newPlayerName.trim()); this.newPlayerName = ''; } },
    removePlayer(i) { this.gameSetup.players.splice(i, 1); },
    async startGame() {
      try {
        const res = await axios.post(`$${API}/games`, { point_limit: this.gameSetup.pointLimit, player_names: this.gameSetup.players });
        this.currentGameId = res.data.game_id;
        this.screen = 'gameplay';
        await this.loadNextCard();
      } catch (e) { alert('Game starten mislukt: ' + e.message); }
    },
    async loadNextCard() {
      try {
        const res = await axios.get(`$${API}/games/$${this.currentGameId}/next-card`);
        this.currentGamePlayer = res.data.current_player;
        this.currentQuestions = res.data.questions;
        this.currentCardId = res.data.card_id;
        const gameRes = await axios.get(`$${API}/games/$${this.currentGameId}`);
        this.gamePlayers = gameRes.data.players;
        this.selectedQuestion = null;
      } catch (e) { alert('Kaart laden mislukt: ' + e.message); }
    },
    selectQuestion(question) { this.selectedQuestion = question; },
    async answerQuestion(actionType) {
      try {
        const res = await axios.post(`$${API}/games/$${this.currentGameId}/answer`, {
          card_id: this.currentCardId,
          question_id: this.selectedQuestion.id,
          action_type: actionType
        });
        if (res.data.game_finished) {
          this.finalScores = res.data.final_scores;
          this.screen = 'finished';
        } else {
          await this.loadNextCard();
        }
      } catch (e) { alert('Antwoord verwerken mislukt: ' + e.message); }
    },
    backToMenu() { this.screen = 'menu'; },
    playAgain() { this.goToGameSetup(); },
    goToAdmin() { this.screen = 'admin'; this.loadAllQuestions(); },
    async addQuestion() {
      if (!this.newQuestion.text.trim()) return;
      try {
        await axios.post(`$${API}/admin/questions`, {
          user_id: this.currentUser.id,
          difficulty: this.newQuestion.difficulty,
          text: this.newQuestion.text.trim()
        });
        this.newQuestion.text = '';
        alert('Vraag toegevoegd!');
        this.loadAllQuestions();
      } catch (e) { alert('Vraag toevoegen mislukt: ' + e.message); }
    },
    async loadAllQuestions() {
      try {
        const res = await axios.get(`$${API}/admin/questions`);
        this.allQuestions = res.data;
      } catch (e) { alert('Vragen laden mislukt: ' + e.message); }
    },
    async deleteQuestion(id) {
      if (!confirm('Weet je zeker dat je deze vraag wilt verwijderen?')) return;
      try {
        await axios.delete(`$${API}/admin/questions/$${id}`, { data: { user_id: this.currentUser.id } });
        this.loadAllQuestions();
      } catch (e) { alert('Vraag verwijderen mislukt: ' + e.message); }
    }
  }
};
</script>
APP_VUE

# Create complete CSS file directly (no curl fallback)
cat > src/assets/style.css << 'STYLE_CSS'
* { margin: 0; padding: 0; box-sizing: border-box; }
body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  min-height: 100vh;
}
.app { min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 20px; }
.screen { width: 100%; max-width: 800px; animation: fadeIn 0.3s ease-in; }
@keyframes fadeIn { from { opacity: 0; transform: translateY(20px); } to { opacity: 1; transform: translateY(0); } }
.container { background: white; border-radius: 20px; padding: 40px; box-shadow: 0 20px 60px rgba(0,0,0,0.3); }
h1 { font-size: 2.5em; margin-bottom: 10px; color: #333; text-align: center; }
h2 { font-size: 1.8em; margin-bottom: 20px; color: #444; text-align: center; }
h3 { font-size: 1.3em; margin-bottom: 15px; color: #555; }
p { text-align: center; color: #666; margin-bottom: 30px; }
.input-field { width: 100%; padding: 15px; margin: 10px 0; border: 2px solid #e0e0e0; border-radius: 10px; font-size: 16px; transition: all 0.3s; }
.input-field:focus { outline: none; border-color: #667eea; box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1); }
.textarea { resize: vertical; font-family: inherit; }
select.input-field { cursor: pointer; }
.form-group { margin-bottom: 20px; }
.form-group label { display: block; margin-bottom: 8px; font-weight: 600; color: #555; }
.btn { width: 100%; padding: 15px; margin: 10px 0; border: none; border-radius: 10px; font-size: 16px; font-weight: 600; cursor: pointer; transition: all 0.3s; }
.btn:hover { transform: translateY(-2px); box-shadow: 0 5px 15px rgba(0,0,0,0.2); }
.btn:active { transform: translateY(0); }
.btn-primary { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }
.btn-secondary { background: #6c757d; color: white; }
.btn-success { background: #48bb78; color: white; }
.btn-danger { background: #f56565; color: white; }
.btn-large { font-size: 18px; padding: 20px; }
.btn-small { width: auto; padding: 8px 15px; font-size: 14px; margin: 0; }
.stats-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 15px; margin: 30px 0; }
.stat-card { background: #f7fafc; padding: 20px; border-radius: 10px; text-align: center; }
.stat-value { font-size: 2.5em; font-weight: bold; color: #667eea; }
.stat-label { font-size: 0.9em; color: #666; margin-top: 5px; }
.player-list { background: #f7fafc; padding: 15px; border-radius: 10px; margin: 15px 0; min-height: 60px; }
.player-item { display: flex; justify-content: space-between; align-items: center; padding: 12px; background: white; margin: 8px 0; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.05); }
.input-with-button { display: flex; gap: 10px; }
.input-with-button .input-field { flex: 1; }
.input-with-button .btn { width: auto; padding: 15px 30px; }
.scoreboard { display: grid; grid-template-columns: repeat(auto-fit, minmax(120px, 1fr)); gap: 10px; margin-bottom: 30px; }
.player-score { background: #f7fafc; padding: 15px; border-radius: 10px; text-align: center; border: 3px solid transparent; transition: all 0.3s; }
.player-score.active { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; border-color: #ffd700; box-shadow: 0 5px 20px rgba(102, 126, 234, 0.4); }
.player-name { font-weight: 600; font-size: 0.9em; margin-bottom: 5px; }
.player-points { font-size: 1.4em; font-weight: bold; }
.turn-indicator { text-align: center; margin: 20px 0; padding: 15px; background: #fff3cd; border-radius: 10px; border: 2px solid #ffc107; }
.turn-indicator h2 { margin: 0; color: #856404; font-size: 1.5em; }
.card-container { margin: 30px 0; }
.card { background: #f7fafc; padding: 20px; border-radius: 15px; box-shadow: 0 5px 15px rgba(0,0,0,0.1); }
.question-option { background: white; padding: 20px; margin: 15px 0; border-radius: 12px; border: 3px solid #e0e0e0; cursor: pointer; transition: all 0.3s; }
.question-option:hover { border-color: #667eea; box-shadow: 0 5px 15px rgba(102, 126, 234, 0.2); transform: translateY(-2px); }
.question-option.selected { border-color: #667eea; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; box-shadow: 0 8px 25px rgba(102, 126, 234, 0.4); }
.question-option.easy { border-left: 6px solid #48bb78; }
.question-option.medium { border-left: 6px solid #ed8936; }
.question-option.hard { border-left: 6px solid #f56565; }
.difficulty-badge { display: inline-block; padding: 5px 12px; border-radius: 20px; font-size: 0.8em; font-weight: bold; margin-bottom: 10px; background: #e0e0e0; color: #555; }
.question-option.selected .difficulty-badge { background: rgba(255,255,255,0.3); color: white; }
.question-text { font-size: 1.1em; margin: 15px 0; line-height: 1.5; }
.points-badge { font-weight: bold; font-size: 0.9em; opacity: 0.8; }
.action-buttons { display: grid; grid-template-columns: 2fr 1fr; gap: 15px; margin-top: 20px; }
.leaderboard { margin: 30px 0; }
.leaderboard-item { display: flex; align-items: center; gap: 20px; padding: 20px; margin: 15px 0; background: white; border-radius: 12px; box-shadow: 0 3px 10px rgba(0,0,0,0.1); transition: all 0.3s; }
.leaderboard-item.winner { background: linear-gradient(135deg, #ffd700 0%, #ffed4e 100%); box-shadow: 0 8px 25px rgba(255, 215, 0, 0.4); transform: scale(1.05); }
.rank { font-size: 2em; font-weight: bold; min-width: 60px; text-align: center; }
.player-info { flex: 1; }
.player-info .name { font-size: 1.3em; font-weight: 600; margin-bottom: 5px; }
.player-info .score { font-size: 1em; color: #666; }
.leaderboard-item.winner .player-info .name { color: #856404; }
.admin-tabs { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-bottom: 30px; }
.admin-tabs .btn { background: #e0e0e0; color: #555; }
.admin-tabs .btn.active { background: #667eea; color: white; }
.admin-section { margin: 30px 0; }
.question-list { max-height: 500px; overflow-y: auto; padding: 10px; background: #f7fafc; border-radius: 10px; }
.question-item { display: flex; justify-content: space-between; align-items: center; padding: 15px; margin: 10px 0; background: white; border-radius: 8px; box-shadow: 0 2px 5px rgba(0,0,0,0.05); }
.question-content { flex: 1; display: flex; align-items: center; gap: 10px; }
.difficulty-tag { display: inline-block; padding: 4px 10px; border-radius: 15px; font-size: 0.8em; font-weight: bold; white-space: nowrap; }
.difficulty-tag.diff-1 { background: #48bb78; color: white; }
.difficulty-tag.diff-2 { background: #ed8936; color: white; }
.difficulty-tag.diff-3 { background: #f56565; color: white; }
@media (max-width: 768px) {
  .container { padding: 20px; }
  h1 { font-size: 2em; }
  .stats-grid { grid-template-columns: 1fr; }
  .scoreboard { grid-template-columns: repeat(2, 1fr); }
  .action-buttons { grid-template-columns: 1fr; }
  .admin-tabs { grid-template-columns: 1fr; }
}
STYLE_CSS

chown -R cardgame:cardgame /home/cardgame/card-game/frontend
cd /home/cardgame/card-game/frontend
sudo -u cardgame npm install

echo "Building frontend..." | tee -a /var/log/card-game-init.log
sudo -u cardgame npm run build

# Copy built files to nginx directory
cp -r dist/* /var/www/card-game/
chown -R www-data:www-data /var/www/card-game

echo "=== Configuring Nginx ===" | tee -a /var/log/card-game-init.log

cat > /etc/nginx/sites-available/card-game << 'NGINX_CONF'
upstream backend {
    server localhost:5000;
}

server {
    listen 80 default_server;
    server_name _;

    root /var/www/card-game;
    index index.html;

    location /api {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
NGINX_CONF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/card-game /etc/nginx/sites-enabled/card-game
nginx -t && systemctl restart nginx
systemctl enable nginx

echo "=== Deployment Complete ===" | tee -a /var/log/card-game-init.log
echo "✅ Backend: http://$INSTANCE_IP:5000" | tee -a /var/log/card-game-init.log
echo "✅ Frontend: http://$INSTANCE_IP" | tee -a /var/log/card-game-init.log
echo "✅ Check logs: sudo journalctl -u card-game-backend -f" | tee -a /var/log/card-game-init.log