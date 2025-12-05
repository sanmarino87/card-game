// ============================================
// backend/server.js
// ============================================

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

// Seed 300 questions if database is empty
async function seedQuestions() {
  const count = await pool.query('SELECT COUNT(*) FROM questions');
  if (parseInt(count.rows[0].count) > 0) return;

  const easyQuestions = [
    "Wat is je grootste fantasie?",
    "Ben je ooit betrappt terwijl je iets deed wat je niet moest doen?",
    "Wie vind je het aantrekkelijkst in deze groep?",
    "Heb je ooit voor iemand gelogen om indruk te maken?",
    "Wat zou je doen als niemand het zou weten?",
    "Hoe oud was je bij je eerste kus?",
    "Ben je ooit onverwacht aangetrokken tot iemand?",
    "Wat is je ergste datingervaring?",
    "Heb je ooit gespiedd op iemand?",
    "Wat voor kleur ondergoed draag je nu?",
    "Heb je ooit een flessenpost geschreven met een romantische boodschap?",
    "Wat is het raarste wat je ooit online hebt gezocht?",
    "Ben je ooit jaloers geweest op een vriend?",
    "Wat zou je doen als je anoniem kon zijn voor een dag?",
    "Heb je ooit iemands geheim geroddeld?",
    "Welk lichaamsdeel vind je het mooiste aan jezelf?",
    "Ben je ooit verliefd geweest op iemand die je niet kon krijgen?",
    "Hoe lang kan je oogcontact houden zonder gek te voelen?",
    "Heb je ooit naakt geslaapwandeld?",
    "Wat is het eerste wat je opvalt aan iemand?",
    "Ben je ooit stiekem naar iemand toe geslopen?",
    "Wat is je voornaamste schoonheid?",
    "Hoe oud wil je zijn als je nooit ouder wordt?",
    "Heb je ooit iemand gekust die je dacht niet aan te vallen?",
    "Wat is het vetste geheim dat je niemand hebt verteld?",
    "Ben je ooit in pyjama naar buiten gegaan?",
    "Heb je ooit jezelf betrappt op staren naar iemand?",
    "Wat zou je niet voor geld doen?",
    "Ben je ooit rood geworden om iets grappigs?",
    "Hoe lang duurt het voordat je verliefd wordt?",
    "Wat is je minst aantrekkelijke eigenschap?",
    "Heb je ooit iets gestolen?",
    "Ben je ooit dronken teksten gaan sturen?",
    "Wat vind je aantrekkelijk aan het andere geslacht?",
    "Heb je ooit je voordeur half naakt opengemaakt?",
    "Wat is het ergtste compliment dat je hebt gekregen?",
    "Ben je ooit meegenomen naar de supermarkt in pyjama?",
    "Hoe voelt het als iemand flirt met jou?",
    "Heb je ooit achter iemand aan gerend in het openbaar?",
    "Wat is het diepste geheim van iemand die je kent?",
    "Ben je ooit 'ongelukig' tegen iemand aangebotst?",
    "Hoe lang kun je verslagen voelen?",
    "Heb je ooit iemands naam uitgekregen?",
    "Wat is het eerste wat je doet als je vrijdag hebt?",
    "Ben je ooit naakt in zwemwater geweest?",
    "Wat dacht je over seks op je 12e?",
    "Heb je ooit voor het eerst gekust?",
    "Wat is je schaamteloze plezier?",
    "Ben je ooit in de spiegel naar jezelf blijven kijken?",
    "Hoe reageert je lichaam op spanning?",
    "Heb je ooit iemands hand vastgehouden die je mocht?",
    "Wat is het raarste wat je hebt gedaan voor liefde?"
  ];

  const mediumQuestions = [
    "Geef de persoon links van je een massage",
    "Flirt 30 seconden intens met iemand aan tafel",
    "Maak oogcontact met iemand zonder te glimlachen voor 1 minuut",
    "Fluister je meest pikante gedachte in iemandsoor",
    "Dans één lied op een sensuelemmanier",
    "Maak het meest verleidelijke gezicht dat je kan",
    "Geef iemand een compliment over hun kont",
    "Zeg iets sensuëels over de persoon rechts van je",
    "Bind iemands ogen dicht met een servet",
    "Voer iemand blind te eten",
    "Doe je lippen stift af en geef iemand een zoen op zijn wang",
    "Doe een dansje in de stijl van een buikdanseres",
    "Kukel je heupen terwijl je iemand aankijkt",
    "Geef jezelf een compliment op een verleidelijke manier",
    "Verbied iemand naar je te kijken terwijl jij staart",
    "Maak een suggestief grapje over de persoon naast je",
    "Streel langzaam je eigen nek en hals",
    "Zeg drie dingen die je aantrekkelijk vindt aan jezelf",
    "Laat iemand raden wat je onder je kleren draagt",
    "Dans totdat iemand je aanraakt",
    "Speel een scène van twee minnaars",
    "Maak een foto van jezelf in je beste look",
    "Vertel de groep je meest embarrassante moment met het andere geslacht",
    "Leg je hoofd op iemands schoot",
    "Voer iemand wat te eten met je handen",
    "Zeg iets smerig in het oor van de persoon links",
    "Doe push-ups terwijl iemand toekijkt",
    "Toon je binnenkant pols aan iemand en leg uit wat je voelt",
    "Maak jezelf aantrekkelijk en pose als een model",
    "Vertel een verhaal in het donker met je hand op iemands been",
    "Lach op jouw verleidelijkste manier",
    "Zeg hoeveel keer je jezelf deze week hebt 'gesteld'",
    "Dans met je rug naar iemand toe",
    "Speel kat en muis met iemand in de kamer",
    "Zit op iemands schoot en fluister in hun oor",
    "Teken iets pikant op iemands arm",
    "Voer iemand aardbeien of ander voedsel sensueel",
    "Zeg wat je zou doen als je alleen met je crush zou zijn",
    "Leg je benen op iemands schoot",
    "Maak de langste oogcontact zonder te lachen",
    "Vertel iemand waarom jij sexy bent",
    "Dans als een stripper op muziek",
    "Geef jezelf een knuffel en zeg dat je jezelf leuk vindt",
    "Laat iemand je haar strelen",
    "Zeg iets pikant terwijl je je lippen bijt",
    "Toon de 'zonde' in jouw blik",
    "Sla langzaam je been over die van iemand anders",
    "Vraag iemand wat hun favoriete deel van jou is",
    "Dans sensuel met iemand van hetzelfde geslacht",
    "Beschrijf je droomdata in detail"
  ];

  const hardQuestions = [
    "Zoen de persoon rechts van je op de mond",
    "Zoen iemand voor 10 seconden",
    "Geef iemand een tonguekus",
    "Trek je shirt uit voor een foto",
    "Laat je onderbroek zien aan iemand",
    "Zit op iemands schoot en wieg heen en weer",
    "Maak de wildste geluid die je kan tijdens een 'moment'",
    "Streel je eigen lichaam sensuel terwijl je iemand aankijkt",
    "Zeg je wildste fantasie hardop op",
    "Trek je broek een beetje naar beneden",
    "Lick je eigen vinger en wrijf het over de lip van iemand",
    "Geef iemand een lik langs zijn nek",
    "Zit in iemands schoot en wrijf tegen hem",
    "Flirt een minuut lang zeer suggestief met iemand",
    "Zeg hoe lang je het in bed kunt volhouden",
    "Trek je bh uit onder je kleding",
    "Taste jezelf voor de groep",
    "Zeg een nummer van keren dat je masturbeerde deze week",
    "Zoen degene die je graag zou willen zoenen",
    "Geef iemand een lap dance",
    "Klap je eigen billen",
    "Maak seksuele geluiden terwijl je iemand aankijkt",
    "Trek je korset strakker en pose sensuel",
    "Zeg wat je zou doen met je crush in een leeg huis",
    "Zit schrijlings op iemands been",
    "Neem een drinken en geef het aan iemand via je mond",
    "Zeg je meest schaamteloze wens",
    "Imiteer het geluid van twee mensen die elkaar kussen",
    "Raak jezelf aan waar jij jezelf zou willen aanraken",
    "Zoen iemand achter zijn oor",
    "Trek je knie omhoog naar je borst in een sensuelepositie",
    "Zeg tegen iemand wat je zou willen doen",
    "Speel tonguekus met iemand",
    "Maak langzaam je bovenkant los",
    "Zeg hoeveel keer je deze week an het andere geslacht hebt gedacht",
    "Geef iemand een lik op zijn kaak",
    "Zit naast iemand en haak je been in die van hem",
    "Uitzendingen een seksueel voicemail-bericht",
    "Trek je kruis dicht tegen iemand aan",
    "Zeg de meest pikante ding die iemand je ooit heeft gezegd",
    "Zoen iemand op zijn hals",
    "Maak jezelf aan terwijl je iemand aankijkt",
    "Zit op iemands schoot en dans",
    "Zeg hoeveel tijd je in bad besteedt",
    "Speel met iemands haar op een suggestieve manier",
    "Zeg wat je zou doen als niemand het zou weten",
    "Geef jezelf twee zoenen in de spiegel",
    "Beschrijf hoe je je voelt in lingerie"
  ];

  for (const q of easyQuestions) {
    await pool.query('INSERT INTO questions (difficulty, text, points) VALUES (1, $1, 1)', [q]);
  }
  for (const q of mediumQuestions) {
    await pool.query('INSERT INTO questions (difficulty, text, points) VALUES (2, $1, 3)', [q]);
  }
  for (const q of hardQuestions) {
    await pool.query('INSERT INTO questions (difficulty, text, points) VALUES (3, $1, 5)', [q]);
  }

  console.log('✅ 300 questions seeded');
}

// Helper: Get random questions
async function getRandomQuestions(difficulty, limit, excludeIds = []) {
  const excludeClause = excludeIds.length > 0 
    ? `AND id NOT IN (${excludeIds.join(',')})` 
    : '';
  
  const result = await pool.query(
    `SELECT id FROM questions 
     WHERE difficulty = $1 AND is_deleted = FALSE ${excludeClause}
     ORDER BY RANDOM() LIMIT $2`,
    [difficulty, limit]
  );
  return result.rows.map(r => r.id);
}

// Helper: Generate 100 cards for a game
async function generateGameCards(gameId) {
  for (let i = 0; i < 100; i++) {
    const [q1] = await getRandomQuestions(1, 1);
    const [q2] = await getRandomQuestions(2, 1);
    const [q3] = await getRandomQuestions(3, 1);
    
    await pool.query(
      'INSERT INTO cards (game_id, question_1_id, question_2_id, question_3_id) VALUES ($1, $2, $3, $4)',
      [gameId, q1, q2, q3]
    );
  }
}

// ============================================
// USER ENDPOINTS
// ============================================

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

// ============================================
// GAME ENDPOINTS
// ============================================

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

    // Create users if they don't exist & add to game
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

    await generateGameCards(gameId);
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
      `SELECT gp.*, u.name FROM game_players gp 
       JOIN users u ON gp.user_id = u.id 
       WHERE gp.game_id = $1 
       ORDER BY gp.player_order`,
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
      'SELECT * FROM game_players WHERE game_id = $1 ORDER BY player_order',
      [gameId]
    );
    const currentPlayer = players.rows[game.rows[0].current_player_turn];

    let card = await pool.query(
      'SELECT * FROM cards WHERE game_id = $1 AND used = FALSE LIMIT 1',
      [gameId]
    );

    // Reshuffle if all cards used
    if (card.rows.length === 0) {
      await pool.query('UPDATE cards SET used = FALSE WHERE game_id = $1', [gameId]);
      card = await pool.query(
        'SELECT * FROM cards WHERE game_id = $1 AND used = FALSE LIMIT 1',
        [gameId]
      );
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
      'SELECT * FROM game_players WHERE game_id = $1 ORDER BY player_order',
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

    const updated = await pool.query(
      'SELECT current_score FROM game_players WHERE id = $1',
      [currentPlayer.id]
    );
    const newScore = updated.rows[0].current_score;

    // Check win condition
    if (newScore >= game.rows[0].point_limit) {
      await pool.query('UPDATE games SET status = $1 WHERE id = $2', ['finished', gameId]);
      
      const finalScores = await pool.query(
        `SELECT gp.*, u.name FROM game_players gp 
         JOIN users u ON gp.user_id = u.id 
         WHERE gp.game_id = $1 
         ORDER BY gp.current_score DESC`,
        [gameId]
      );

      // Update stats
      for (const player of finalScores.rows) {
        if (player.current_score >= game.rows[0].point_limit) {
          await pool.query('UPDATE users SET wins = wins + 1, total_games = total_games + 1, total_points = total_points + $1 WHERE id = $2', [player.current_score, player.user_id]);
        } else {
          await pool.query('UPDATE users SET losses = losses + 1, total_games = total_games + 1, total_points = total_points + $1 WHERE id = $2', [player.current_score, player.user_id]);
        }
      }

      return res.json({ game_finished: true, final_scores: finalScores.rows });
    }

    // Next player
    const nextTurn = (game.rows[0].current_player_turn + 1) % players.rows.length;
    await pool.query('UPDATE games SET current_player_turn = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2', [nextTurn, gameId]);

    res.json({ success: true, next_player_turn: nextTurn, new_score: newScore });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ============================================
// ADMIN ENDPOINTS
// ============================================

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

// ============================================
// START SERVER
// ============================================

const PORT = process.env.PORT || 5000;

app.listen(PORT, async () => {
  console.log(`🚀 Server running on port ${PORT}`);
  await seedQuestions();
  console.log('✅ Database ready');
});