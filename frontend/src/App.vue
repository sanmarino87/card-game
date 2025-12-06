<template>
  <div class="app">
    <!-- LOGIN SCREEN -->
    <div v-if="!currentUser" class="screen">
      <div class="container">
        <h1>🎴 Kaartspel</h1>
        <p>Card Game</p>
        <input 
          v-model="nameInput" 
          @keyup.enter="login" 
          placeholder="Voer je naam in..."
          class="input-field"
        />
        <button @click="login" class="btn btn-primary">Start Spelen</button>
      </div>
    </div>

    <!-- MAIN MENU -->
    <div v-else-if="screen === 'menu'" class="screen">
      <div class="container">
        <h1>Welkom, {{ currentUser.name }}! 👋</h1>
        <div class="stats-grid">
          <div class="stat-card">
            <div class="stat-value">{{ currentUser.total_games }}</div>
            <div class="stat-label">Potjes</div>
          </div>
          <div class="stat-card">
            <div class="stat-value">{{ currentUser.wins }}</div>
            <div class="stat-label">Wins</div>
          </div>
          <div class="stat-card">
            <div class="stat-value">{{ avgPoints }}</div>
            <div class="stat-label">Avg Punten</div>
          </div>
        </div>
        <button @click="goToGameSetup" class="btn btn-primary">🎮 Nieuw Potje</button>
        <button v-if="currentUser.is_admin" @click="goToAdmin" class="btn btn-secondary">⚙️ Admin Panel</button>
        <button @click="logout" class="btn btn-danger">Uitloggen</button>
      </div>
    </div>

    <!-- GAME SETUP -->
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
            <input 
              v-model="newPlayerName" 
              @keyup.enter="addPlayer" 
              placeholder="Naam van speler..."
              class="input-field"
            />
            <button @click="addPlayer" class="btn btn-secondary">Toevoegen</button>
          </div>
        </div>
        <button 
          v-if="gameSetup.players.length >= 2" 
          @click="startGame" 
          class="btn btn-primary btn-large"
        >
          🚀 Start Potje
        </button>
        <button @click="backToMenu" class="btn btn-secondary">Terug</button>
      </div>
    </div>

    <!-- GAMEPLAY -->
    <div v-else-if="screen === 'gameplay'" class="screen gameplay-screen">
      <div class="container">
        <!-- Scoreboard -->
        <div class="scoreboard">
          <div 
            v-for="player in gamePlayers" 
            :key="player.id" 
            class="player-score"
            :class="{ active: player.id === currentGamePlayer.id }"
          >
            <div class="player-name">{{ player.name }}</div>
            <div class="player-points">{{ player.current_score }} pts</div>
          </div>
        </div>

        <!-- Current Player -->
        <div class="turn-indicator">
          <h2>{{ currentGamePlayer.name }} is aan de beurt</h2>
        </div>

        <!-- Card with Questions -->
        <div class="card-container">
          <div class="card">
            <div 
              v-for="(q, i) in currentQuestions" 
              :key="q.id" 
              class="question-option"
              :class="{ 
                selected: selectedQuestion?.id === q.id,
                easy: i === 0,
                medium: i === 1,
                hard: i === 2
              }"
              @click="selectQuestion(q)"
            >
              <div class="difficulty-badge">{{ ['Makkelijk', 'Medium', 'Moeilijk'][i] }}</div>
              <div class="question-text">{{ q.text }}</div>
              <div class="points-badge">+{{ q.points }} punten</div>
            </div>
          </div>
        </div>

        <!-- Action Buttons -->
        <div v-if="selectedQuestion" class="action-buttons">
          <button @click="answerQuestion('answered')" class="btn btn-success btn-large">
            ✓ Gedaan!
          </button>
          <button @click="answerQuestion('refused')" class="btn btn-danger">
            ✕ Weigeren (-5 pts)
          </button>
        </div>
      </div>
    </div>

    <!-- GAME FINISHED -->
    <div v-else-if="screen === 'finished'" class="screen">
      <div class="container">
        <h1>🏆 Potje Voorbij!</h1>
        <div class="leaderboard">
          <div 
            v-for="(player, i) in finalScores" 
            :key="player.id" 
            class="leaderboard-item"
            :class="{ winner: i === 0 }"
          >
            <div class="rank">{{ ['🥇', '🥈', '🥉'][i] || `#${i + 1}` }}</div>
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

    <!-- ADMIN PANEL -->
    <div v-else-if="screen === 'admin'" class="screen">
      <div class="container">
        <h2>⚙️ Admin Panel</h2>
        <div class="admin-tabs">
          <button 
            @click="adminTab = 'add'" 
            :class="{ active: adminTab === 'add' }"
            class="btn"
          >
            Vraag Toevoegen
          </button>
          <button 
            @click="adminTab = 'manage'" 
            :class="{ active: adminTab === 'manage' }"
            class="btn"
          >
            Vragen Beheren
          </button>
        </div>

        <!-- Add Question -->
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
            <textarea 
              v-model="newQuestion.text" 
              placeholder="Voer de vraag of opdracht in..."
              class="input-field textarea"
              rows="4"
            ></textarea>
          </div>
          <button @click="addQuestion" class="btn btn-primary">➕ Voeg Toe</button>
        </div>

        <!-- Manage Questions -->
        <div v-if="adminTab === 'manage'" class="admin-section">
          <h3>Alle Vragen ({{ allQuestions.length }})</h3>
          <div class="question-list">
            <div v-for="q in allQuestions" :key="q.id" class="question-item">
              <div class="question-content">
                <span class="difficulty-tag" :class="`diff-${q.difficulty}`">
                  {{ ['Makkelijk', 'Medium', 'Moeilijk'][q.difficulty - 1] }}
                </span>
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

const API = import.meta.env.VITE_API_URL || 'http://localhost:5000/api';

export default {
  data() {
    return {
      currentUser: null,
      nameInput: '',
      screen: 'menu',
      gameSetup: {
        pointLimit: 50,
        players: []
      },
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
      newQuestion: {
        difficulty: 1,
        text: ''
      }
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
        const res = await axios.post(`${API}/users`, { name: this.nameInput.trim() });
        this.currentUser = res.data;
        this.screen = 'menu';
      } catch (e) {
        alert('Login mislukt: ' + e.message);
      }
    },

    logout() {
      this.currentUser = null;
      this.nameInput = '';
      this.screen = 'menu';
    },

    goToGameSetup() {
      this.gameSetup.players = [this.currentUser.name];
      this.newPlayerName = '';
      this.screen = 'setup';
    },

    addPlayer() {
      if (!this.newPlayerName.trim()) return;
      this.gameSetup.players.push(this.newPlayerName.trim());
      this.newPlayerName = '';
    },

    removePlayer(i) {
      this.gameSetup.players.splice(i, 1);
    },

    async startGame() {
      try {
        const res = await axios.post(`${API}/games`, {
          point_limit: this.gameSetup.pointLimit,
          player_names: this.gameSetup.players
        });
        this.currentGameId = res.data.game_id;
        this.screen = 'gameplay';
        await this.loadNextCard();
      } catch (e) {
        alert('Game starten mislukt: ' + e.message);
      }
    },

    async loadNextCard() {
      try {
        const res = await axios.get(`${API}/games/${this.currentGameId}/next-card`);
        this.currentGamePlayer = res.data.current_player;
        this.currentQuestions = res.data.questions;
        this.currentCardId = res.data.card_id;
        
        const gameRes = await axios.get(`${API}/games/${this.currentGameId}`);
        this.gamePlayers = gameRes.data.players;
        
        this.selectedQuestion = null;
      } catch (e) {
        alert('Kaart laden mislukt: ' + e.message);
      }
    },

    selectQuestion(question) {
      this.selectedQuestion = question;
    },

    async answerQuestion(actionType) {
      try {
        const res = await axios.post(`${API}/games/${this.currentGameId}/answer`, {
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
      } catch (e) {
        alert('Antwoord verwerken mislukt: ' + e.message);
      }
    },

    backToMenu() {
      this.screen = 'menu';
    },

    playAgain() {
      this.goToGameSetup();
    },

    goToAdmin() {
      this.screen = 'admin';
      this.loadAllQuestions();
    },

    async addQuestion() {
      if (!this.newQuestion.text.trim()) return;
      try {
        await axios.post(`${API}/admin/questions`, {
          user_id: this.currentUser.id,
          difficulty: this.newQuestion.difficulty,
          text: this.newQuestion.text.trim()
        });
        this.newQuestion.text = '';
        alert('Vraag toegevoegd!');
        this.loadAllQuestions();
      } catch (e) {
        alert('Vraag toevoegen mislukt: ' + e.message);
      }
    },

    async loadAllQuestions() {
      try {
        const res = await axios.get(`${API}/admin/questions`);
        this.allQuestions = res.data;
      } catch (e) {
        alert('Vragen laden mislukt: ' + e.message);
      }
    },

    async deleteQuestion(id) {
      if (!confirm('Weet je zeker dat je deze vraag wilt verwijderen?')) return;
      try {
        await axios.delete(`${API}/admin/questions/${id}`, {
          data: { user_id: this.currentUser.id }
        });
        this.loadAllQuestions();
      } catch (e) {
        alert('Vraag verwijderen mislukt: ' + e.message);
      }
    }
  }
};
</script>