const express = require('express');
const { Client } = require('pg');
const helmet = require('helmet');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');

const app = express();
const PORT = process.env.PORT || 3002;

// Database connection
const dbClient = new Client({
  connectionString: process.env.DATABASE_URL || 'postgresql://admin:admin123@localhost:5432/esport_coach'
});

// Connect to database
dbClient.connect().catch(console.error);

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'user-service',
    timestamp: new Date().toISOString()
  });
});

// Get user profile
app.get('/users/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await dbClient.query(
      'SELECT id, email, phone, preferences, created_at, updated_at FROM users WHERE id = $1',
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({ error: 'Failed to get user' });
  }
});

// Update user profile
app.put('/users/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { phone, preferences } = req.body;
    
    const result = await dbClient.query(
      `UPDATE users 
       SET phone = COALESCE($2, phone), 
           preferences = COALESCE($3, preferences), 
           updated_at = CURRENT_TIMESTAMP 
       WHERE id = $1 
       RETURNING id, email, phone, preferences, created_at, updated_at`,
      [id, phone, preferences]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Update user error:', error);
    res.status(500).json({ error: 'Failed to update user' });
  }
});

// Create user (internal endpoint, typically called by auth service)
app.post('/users', async (req, res) => {
  try {
    const { email, authProviderId, phone } = req.body;
    
    if (!email) {
      return res.status(400).json({ error: 'Email is required' });
    }

    const id = uuidv4();
    
    const result = await dbClient.query(
      `INSERT INTO users (id, email, auth_provider_id, phone) 
       VALUES ($1, $2, $3, $4) 
       RETURNING id, email, phone, preferences, created_at`,
      [id, email, authProviderId, phone]
    );

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Create user error:', error);
    if (error.code === '23505') { // Unique constraint violation
      res.status(409).json({ error: 'User already exists' });
    } else {
      res.status(500).json({ error: 'Failed to create user' });
    }
  }
});

// Delete user
app.delete('/users/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await dbClient.query('DELETE FROM users WHERE id = $1', [id]);
    
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.status(204).send();
  } catch (error) {
    console.error('Delete user error:', error);
    res.status(500).json({ error: 'Failed to delete user' });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`User Service running on port ${PORT}`);
});

module.exports = app;