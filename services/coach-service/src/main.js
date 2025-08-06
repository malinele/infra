const express = require('express');
const { Client } = require('pg');
const helmet = require('helmet');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');

const app = express();
const PORT = process.env.PORT || 3003;

// Database connection
const dbClient = new Client({
  connectionString: process.env.DATABASE_URL || 'postgresql://admin:admin123@localhost:5432/esport_coach'
});

dbClient.connect().catch(console.error);

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'coach-service',
    timestamp: new Date().toISOString()
  });
});

// Get all coaches with filtering
app.get('/coaches', async (req, res) => {
  try {
    const { game, language, maxRate, minRating, page = 1, limit = 10 } = req.query;
    const offset = (page - 1) * limit;
    
    let query = `
      SELECT c.*, u.email, 
             COALESCE(AVG(r.score), 0) as average_rating,
             COUNT(r.score) as total_reviews
      FROM coaches c 
      JOIN users u ON c.user_id = u.id 
      LEFT JOIN ratings r ON r.booking_id IN (
        SELECT id FROM bookings WHERE coach_id = c.id
      )
      WHERE c.status = 'verified'
    `;
    
    const params = [];
    let paramIndex = 1;
    
    if (game) {
      query += ` AND $${paramIndex} = ANY(c.games)`;
      params.push(game);
      paramIndex++;
    }
    
    if (language) {
      query += ` AND $${paramIndex} = ANY(c.languages)`;
      params.push(language);
      paramIndex++;
    }
    
    if (maxRate) {
      query += ` AND c.hourly_rate <= $${paramIndex}`;
      params.push(parseFloat(maxRate));
      paramIndex++;
    }
    
    query += `
      GROUP BY c.id, u.email
      ORDER BY average_rating DESC, c.created_at DESC
      LIMIT $${paramIndex} OFFSET $${paramIndex + 1}
    `;
    
    params.push(parseInt(limit), offset);
    
    const result = await dbClient.query(query, params);
    
    res.json({
      coaches: result.rows,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: result.rows.length
      }
    });
  } catch (error) {
    console.error('Get coaches error:', error);
    res.status(500).json({ error: 'Failed to get coaches' });
  }
});

// Get coach by ID
app.get('/coaches/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await dbClient.query(`
      SELECT c.*, u.email,
             COALESCE(AVG(r.score), 0) as average_rating,
             COUNT(r.score) as total_reviews
      FROM coaches c 
      JOIN users u ON c.user_id = u.id 
      LEFT JOIN ratings r ON r.booking_id IN (
        SELECT id FROM bookings WHERE coach_id = c.id
      )
      WHERE c.id = $1
      GROUP BY c.id, u.email
    `, [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Coach not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Get coach error:', error);
    res.status(500).json({ error: 'Failed to get coach' });
  }
});

// Create coach profile
app.post('/coaches', async (req, res) => {
  try {
    const { userId, displayName, bio, languages = [], games = [], hourlyRate } = req.body;
    
    if (!userId || !displayName) {
      return res.status(400).json({ error: 'User ID and display name are required' });
    }

    const id = uuidv4();
    
    const result = await dbClient.query(`
      INSERT INTO coaches (id, user_id, display_name, bio, languages, games, hourly_rate) 
      VALUES ($1, $2, $3, $4, $5, $6, $7) 
      RETURNING *
    `, [id, userId, displayName, bio, languages, games, hourlyRate]);

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Create coach error:', error);
    if (error.code === '23505') {
      res.status(409).json({ error: 'Coach profile already exists for this user' });
    } else {
      res.status(500).json({ error: 'Failed to create coach profile' });
    }
  }
});

// Update coach profile
app.put('/coaches/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { displayName, bio, languages, games, hourlyRate } = req.body;
    
    const result = await dbClient.query(`
      UPDATE coaches 
      SET display_name = COALESCE($2, display_name),
          bio = COALESCE($3, bio),
          languages = COALESCE($4, languages),
          games = COALESCE($5, games),
          hourly_rate = COALESCE($6, hourly_rate),
          updated_at = CURRENT_TIMESTAMP
      WHERE id = $1 
      RETURNING *
    `, [id, displayName, bio, languages, games, hourlyRate]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Coach not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Update coach error:', error);
    res.status(500).json({ error: 'Failed to update coach' });
  }
});

// Get coach availability
app.get('/coaches/:id/availability', async (req, res) => {
  try {
    const { id } = req.params;
    const { from, to } = req.query;
    
    let query = 'SELECT * FROM availability WHERE coach_id = $1';
    const params = [id];
    
    if (from) {
      query += ' AND start_time >= $2';
      params.push(from);
    }
    
    if (to) {
      query += ` AND end_time <= $${params.length + 1}`;
      params.push(to);
    }
    
    query += ' ORDER BY start_time';
    
    const result = await dbClient.query(query, params);
    res.json(result.rows);
  } catch (error) {
    console.error('Get availability error:', error);
    res.status(500).json({ error: 'Failed to get availability' });
  }
});

// Add availability slot
app.post('/coaches/:id/availability', async (req, res) => {
  try {
    const { id } = req.params;
    const { startTime, endTime, isRecurring = false, timezone = 'UTC' } = req.body;
    
    if (!startTime || !endTime) {
      return res.status(400).json({ error: 'Start time and end time are required' });
    }

    const slotId = uuidv4();
    
    const result = await dbClient.query(`
      INSERT INTO availability (id, coach_id, start_time, end_time, is_recurring, timezone) 
      VALUES ($1, $2, $3, $4, $5, $6) 
      RETURNING *
    `, [slotId, id, startTime, endTime, isRecurring, timezone]);

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Add availability error:', error);
    res.status(500).json({ error: 'Failed to add availability' });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Coach Service running on port ${PORT}`);
});

module.exports = app;