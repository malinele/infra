const express = require('express');
const { Client } = require('pg');
const helmet = require('helmet');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');

const app = express();
const PORT = process.env.PORT || 3008;

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
    service: 'ratings-service',
    timestamp: new Date().toISOString()
  });
});

// Submit rating
app.post('/ratings', async (req, res) => {
  try {
    const { bookingId, score, comment } = req.body;
    
    if (!bookingId || !score) {
      return res.status(400).json({ 
        error: 'Booking ID and score are required' 
      });
    }

    if (score < 1 || score > 5) {
      return res.status(400).json({ 
        error: 'Score must be between 1 and 5' 
      });
    }

    // Check if booking exists and is completed
    const bookingResult = await dbClient.query(
      'SELECT * FROM bookings WHERE id = $1 AND status = $2',
      [bookingId, 'completed']
    );

    if (bookingResult.rows.length === 0) {
      return res.status(404).json({ 
        error: 'Completed booking not found' 
      });
    }

    // Check if rating already exists
    const existingRating = await dbClient.query(
      'SELECT id FROM ratings WHERE booking_id = $1',
      [bookingId]
    );

    if (existingRating.rows.length > 0) {
      return res.status(409).json({ 
        error: 'Rating already exists for this booking' 
      });
    }

    const ratingId = uuidv4();
    
    const result = await dbClient.query(`
      INSERT INTO ratings (id, booking_id, score, comment) 
      VALUES ($1, $2, $3, $4) 
      RETURNING *
    `, [ratingId, bookingId, score, comment]);

    const rating = result.rows[0];
    
    // Emit rating event
    console.log('RatingSubmitted event:', { ratingId, bookingId, score });

    res.status(201).json(rating);
  } catch (error) {
    console.error('Submit rating error:', error);
    res.status(500).json({ error: 'Failed to submit rating' });
  }
});

// Get ratings for a coach
app.get('/coaches/:coachId/ratings', async (req, res) => {
  try {
    const { coachId } = req.params;
    const { page = 1, limit = 10 } = req.query;
    const offset = (page - 1) * limit;
    
    const result = await dbClient.query(`
      SELECT r.*, 
             u.email as reviewer_email,
             b.starts_at as session_date
      FROM ratings r
      JOIN bookings b ON r.booking_id = b.id
      JOIN users u ON b.player_id = u.id
      WHERE b.coach_id = $1
      ORDER BY r.created_at DESC
      LIMIT $2 OFFSET $3
    `, [coachId, parseInt(limit), offset]);

    // Get rating statistics
    const statsResult = await dbClient.query(`
      SELECT 
        COUNT(*) as total_ratings,
        ROUND(AVG(r.score), 2) as average_rating,
        COUNT(CASE WHEN r.score = 5 THEN 1 END) as five_stars,
        COUNT(CASE WHEN r.score = 4 THEN 1 END) as four_stars,
        COUNT(CASE WHEN r.score = 3 THEN 1 END) as three_stars,
        COUNT(CASE WHEN r.score = 2 THEN 1 END) as two_stars,
        COUNT(CASE WHEN r.score = 1 THEN 1 END) as one_star
      FROM ratings r
      JOIN bookings b ON r.booking_id = b.id
      WHERE b.coach_id = $1
    `, [coachId]);

    res.json({
      ratings: result.rows,
      statistics: statsResult.rows[0] || {
        total_ratings: 0,
        average_rating: 0,
        five_stars: 0,
        four_stars: 0,
        three_stars: 0,
        two_stars: 0,
        one_star: 0
      },
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: result.rows.length
      }
    });
  } catch (error) {
    console.error('Get coach ratings error:', error);
    res.status(500).json({ error: 'Failed to get coach ratings' });
  }
});

// Get rating by booking
app.get('/bookings/:bookingId/rating', async (req, res) => {
  try {
    const { bookingId } = req.params;
    
    const result = await dbClient.query(`
      SELECT r.*, 
             b.coach_id,
             b.player_id,
             c.display_name as coach_name,
             u.email as player_email
      FROM ratings r
      JOIN bookings b ON r.booking_id = b.id
      JOIN coaches c ON b.coach_id = c.id
      JOIN users u ON b.player_id = u.id
      WHERE r.booking_id = $1
    `, [bookingId]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Rating not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Get rating error:', error);
    res.status(500).json({ error: 'Failed to get rating' });
  }
});

// Update rating
app.put('/ratings/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { score, comment } = req.body;
    
    if (score && (score < 1 || score > 5)) {
      return res.status(400).json({ 
        error: 'Score must be between 1 and 5' 
      });
    }

    const result = await dbClient.query(`
      UPDATE ratings 
      SET score = COALESCE($2, score),
          comment = COALESCE($3, comment)
      WHERE id = $1 
      RETURNING *
    `, [id, score, comment]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Rating not found' });
    }

    console.log('Rating updated:', { ratingId: id, score, comment });

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Update rating error:', error);
    res.status(500).json({ error: 'Failed to update rating' });
  }
});

// Delete rating
app.delete('/ratings/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await dbClient.query('DELETE FROM ratings WHERE id = $1', [id]);
    
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Rating not found' });
    }

    console.log('Rating deleted:', { ratingId: id });

    res.status(204).send();
  } catch (error) {
    console.error('Delete rating error:', error);
    res.status(500).json({ error: 'Failed to delete rating' });
  }
});

// Get top-rated coaches
app.get('/coaches/top-rated', async (req, res) => {
  try {
    const { limit = 10 } = req.query;
    
    const result = await dbClient.query(`
      SELECT 
        c.*,
        u.email,
        ROUND(AVG(r.score), 2) as average_rating,
        COUNT(r.id) as total_ratings
      FROM coaches c
      JOIN users u ON c.user_id = u.id
      JOIN bookings b ON c.id = b.coach_id
      JOIN ratings r ON b.id = r.booking_id
      WHERE c.status = 'verified'
      GROUP BY c.id, u.email
      HAVING COUNT(r.id) >= 3
      ORDER BY average_rating DESC, total_ratings DESC
      LIMIT $1
    `, [parseInt(limit)]);

    res.json({
      coaches: result.rows,
      criteria: {
        minimum_ratings: 3,
        sort_by: 'average_rating_desc'
      }
    });
  } catch (error) {
    console.error('Get top-rated coaches error:', error);
    res.status(500).json({ error: 'Failed to get top-rated coaches' });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Ratings Service running on port ${PORT}`);
  console.log('Ratings and review management ready');
});

module.exports = app;