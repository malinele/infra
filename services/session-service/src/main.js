const express = require('express');
const { Client } = require('pg');
const helmet = require('helmet');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');
const moment = require('moment');

const app = express();
const PORT = process.env.PORT || 3004;

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
    service: 'session-service',
    timestamp: new Date().toISOString()
  });
});

// Create booking
app.post('/bookings', async (req, res) => {
  try {
    const { 
      playerId, 
      coachId, 
      startsAt, 
      durationMinutes = 60, 
      timezone = 'UTC' 
    } = req.body;
    
    if (!playerId || !coachId || !startsAt) {
      return res.status(400).json({ 
        error: 'Player ID, Coach ID, and start time are required' 
      });
    }

    // Check for conflicts (simplified conflict detection)
    const conflictCheck = await dbClient.query(`
      SELECT id FROM bookings 
      WHERE coach_id = $1 
        AND starts_at <= $2 
        AND (starts_at + duration) > $2
        AND status NOT IN ('cancelled', 'completed')
    `, [coachId, startsAt]);

    if (conflictCheck.rows.length > 0) {
      return res.status(409).json({ error: 'Time slot already booked' });
    }

    const bookingId = uuidv4();
    const duration = `${durationMinutes} minutes`;
    
    const result = await dbClient.query(`
      INSERT INTO bookings (id, player_id, coach_id, starts_at, duration, timezone, status) 
      VALUES ($1, $2, $3, $4, $5, $6, $7) 
      RETURNING *
    `, [bookingId, playerId, coachId, startsAt, duration, timezone, 'confirmed']);

    // Emit booking created event (placeholder for event publishing)
    console.log('BookingCreated event:', { bookingId, playerId, coachId, startsAt });

    res.status(201).json({
      bookingId: result.rows[0].id,
      status: result.rows[0].status,
      booking: result.rows[0]
    });
  } catch (error) {
    console.error('Create booking error:', error);
    res.status(500).json({ error: 'Failed to create booking' });
  }
});

// Get bookings for a user (player or coach)
app.get('/bookings', async (req, res) => {
  try {
    const { userId, role, status, page = 1, limit = 10 } = req.query;
    
    if (!userId || !role) {
      return res.status(400).json({ error: 'User ID and role are required' });
    }

    const offset = (page - 1) * limit;
    let query;
    let params;
    
    if (role === 'player') {
      query = `
        SELECT b.*, 
               c.display_name as coach_name,
               u.email as coach_email
        FROM bookings b
        JOIN coaches c ON b.coach_id = c.id
        JOIN users u ON c.user_id = u.id
        WHERE b.player_id = $1
      `;
      params = [userId];
    } else if (role === 'coach') {
      query = `
        SELECT b.*, 
               u.email as player_email
        FROM bookings b
        JOIN users u ON b.player_id = u.id
        WHERE b.coach_id = (SELECT id FROM coaches WHERE user_id = $1)
      `;
      params = [userId];
    } else {
      return res.status(400).json({ error: 'Invalid role' });
    }
    
    if (status) {
      query += ` AND b.status = $${params.length + 1}`;
      params.push(status);
    }
    
    query += ` ORDER BY b.starts_at DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
    params.push(parseInt(limit), offset);
    
    const result = await dbClient.query(query, params);
    
    res.json({
      bookings: result.rows,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: result.rows.length
      }
    });
  } catch (error) {
    console.error('Get bookings error:', error);
    res.status(500).json({ error: 'Failed to get bookings' });
  }
});

// Get booking by ID
app.get('/bookings/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await dbClient.query(`
      SELECT b.*, 
             c.display_name as coach_name,
             u1.email as coach_email,
             u2.email as player_email
      FROM bookings b
      JOIN coaches c ON b.coach_id = c.id
      JOIN users u1 ON c.user_id = u1.id
      JOIN users u2 ON b.player_id = u2.id
      WHERE b.id = $1
    `, [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Booking not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Get booking error:', error);
    res.status(500).json({ error: 'Failed to get booking' });
  }
});

// Update booking status
app.put('/bookings/:id/status', async (req, res) => {
  try {
    const { id } = req.params;
    const { status, userId } = req.body;
    
    if (!status) {
      return res.status(400).json({ error: 'Status is required' });
    }

    const validStatuses = ['confirmed', 'in_progress', 'completed', 'cancelled'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ error: 'Invalid status' });
    }

    const result = await dbClient.query(`
      UPDATE bookings 
      SET status = $1, updated_at = CURRENT_TIMESTAMP 
      WHERE id = $2 
      RETURNING *
    `, [status, id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Booking not found' });
    }

    // Emit status change event
    console.log('BookingStatusChanged event:', { bookingId: id, status, userId });

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Update booking status error:', error);
    res.status(500).json({ error: 'Failed to update booking status' });
  }
});

// Cancel booking
app.post('/bookings/:id/cancel', async (req, res) => {
  try {
    const { id } = req.params;
    const { userId, reason } = req.body;
    
    // Check if booking can be cancelled (simplified policy)
    const booking = await dbClient.query(
      'SELECT * FROM bookings WHERE id = $1',
      [id]
    );

    if (booking.rows.length === 0) {
      return res.status(404).json({ error: 'Booking not found' });
    }

    const bookingData = booking.rows[0];
    const now = new Date();
    const startsAt = new Date(bookingData.starts_at);
    const hoursUntilStart = (startsAt - now) / (1000 * 60 * 60);

    // Allow cancellation if more than 2 hours before start
    if (hoursUntilStart < 2 && bookingData.status === 'confirmed') {
      return res.status(400).json({ 
        error: 'Cannot cancel booking less than 2 hours before start time' 
      });
    }

    const result = await dbClient.query(`
      UPDATE bookings 
      SET status = 'cancelled', updated_at = CURRENT_TIMESTAMP 
      WHERE id = $1 
      RETURNING *
    `, [id]);

    // Emit cancellation event
    console.log('BookingCancelled event:', { bookingId: id, userId, reason, hoursUntilStart });

    res.json({ 
      message: 'Booking cancelled successfully',
      booking: result.rows[0],
      refundEligible: hoursUntilStart >= 24
    });
  } catch (error) {
    console.error('Cancel booking error:', error);
    res.status(500).json({ error: 'Failed to cancel booking' });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Session Service running on port ${PORT}`);
});

module.exports = app;