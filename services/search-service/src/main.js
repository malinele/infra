const express = require('express');
const { Client } = require('pg');
const helmet = require('helmet');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');

const app = express();
const PORT = process.env.PORT || 3009;

// Database connection
const dbClient = new Client({
  connectionString: process.env.DATABASE_URL || 'postgresql://admin:admin123@localhost:5432/esport_coach'
});

dbClient.connect().catch(console.error);

// Elasticsearch client (mock for now)
const esClient = {
  search: async (params) => {
    // Mock Elasticsearch response
    return {
      hits: {
        total: { value: 0 },
        hits: []
      }
    };
  },
  index: async (params) => {
    console.log('Indexing document:', params);
    return { result: 'created' };
  }
};

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'search-service',
    timestamp: new Date().toISOString()
  });
});

// Search coaches
app.get('/search/coaches', async (req, res) => {
  try {
    const { 
      q,           // General search query
      game,        // Specific game
      language,    // Language preference
      minRating,   // Minimum rating
      maxRate,     // Maximum hourly rate
      minRate,     // Minimum hourly rate
      availability, // Available now/today/this week
      page = 1,
      limit = 12
    } = req.query;

    const offset = (page - 1) * limit;
    
    // Build dynamic SQL query
    let query = `
      SELECT 
        c.*,
        u.email,
        COALESCE(AVG(r.score), 0) as average_rating,
        COUNT(r.score) as total_reviews,
        CASE 
          WHEN COUNT(a.id) > 0 THEN true 
          ELSE false 
        END as has_availability
      FROM coaches c 
      JOIN users u ON c.user_id = u.id 
      LEFT JOIN bookings b ON c.id = b.coach_id
      LEFT JOIN ratings r ON b.id = r.booking_id
      LEFT JOIN availability a ON c.id = a.coach_id AND a.start_time > NOW()
      WHERE c.status = 'verified'
    `;
    
    const params = [];
    let paramIndex = 1;
    
    // Text search in display_name and bio
    if (q) {
      query += ` AND (c.display_name ILIKE $${paramIndex} OR c.bio ILIKE $${paramIndex})`;
      params.push(`%${q}%`);
      paramIndex++;
    }
    
    // Game filter
    if (game) {
      query += ` AND $${paramIndex} = ANY(c.games)`;
      params.push(game);
      paramIndex++;
    }
    
    // Language filter
    if (language) {
      query += ` AND $${paramIndex} = ANY(c.languages)`;
      params.push(language);
      paramIndex++;
    }
    
    // Rate filters
    if (maxRate) {
      query += ` AND c.hourly_rate <= $${paramIndex}`;
      params.push(parseFloat(maxRate));
      paramIndex++;
    }
    
    if (minRate) {
      query += ` AND c.hourly_rate >= $${paramIndex}`;
      params.push(parseFloat(minRate));
      paramIndex++;
    }
    
    query += `
      GROUP BY c.id, u.email
    `;
    
    // Rating filter (applied after GROUP BY)
    if (minRating) {
      query += ` HAVING COALESCE(AVG(r.score), 0) >= ${parseFloat(minRating)}`;
    }
    
    // Sorting
    query += `
      ORDER BY 
        CASE WHEN COUNT(a.id) > 0 THEN 0 ELSE 1 END, -- Available coaches first
        average_rating DESC, 
        total_reviews DESC,
        c.created_at DESC
      LIMIT $${paramIndex} OFFSET $${paramIndex + 1}
    `;
    
    params.push(parseInt(limit), offset);
    
    const result = await dbClient.query(query, params);
    
    // Get total count for pagination
    let countQuery = `
      SELECT COUNT(DISTINCT c.id) as total
      FROM coaches c 
      JOIN users u ON c.user_id = u.id 
      LEFT JOIN bookings b ON c.id = b.coach_id
      LEFT JOIN ratings r ON b.id = r.booking_id
      WHERE c.status = 'verified'
    `;
    
    // Apply same filters for count
    let countParams = [];
    let countParamIndex = 1;
    
    if (q) {
      countQuery += ` AND (c.display_name ILIKE $${countParamIndex} OR c.bio ILIKE $${countParamIndex})`;
      countParams.push(`%${q}%`);
      countParamIndex++;
    }
    
    if (game) {
      countQuery += ` AND $${countParamIndex} = ANY(c.games)`;
      countParams.push(game);
      countParamIndex++;
    }
    
    if (language) {
      countQuery += ` AND $${countParamIndex} = ANY(c.languages)`;
      countParams.push(language);
      countParamIndex++;
    }
    
    if (maxRate) {
      countQuery += ` AND c.hourly_rate <= $${countParamIndex}`;
      countParams.push(parseFloat(maxRate));
      countParamIndex++;
    }
    
    if (minRate) {
      countQuery += ` AND c.hourly_rate >= $${countParamIndex}`;
      countParams.push(parseFloat(minRate));
      countParamIndex++;
    }
    
    const countResult = await dbClient.query(countQuery, countParams);
    const total = parseInt(countResult.rows[0].total);
    
    res.json({
      coaches: result.rows,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        totalPages: Math.ceil(total / limit)
      },
      filters: {
        query: q,
        game,
        language,
        minRating,
        maxRate,
        minRate,
        availability
      }
    });
  } catch (error) {
    console.error('Search coaches error:', error);
    res.status(500).json({ error: 'Failed to search coaches' });
  }
});

// Get search suggestions
app.get('/search/suggestions', async (req, res) => {
  try {
    const { q, type = 'all' } = req.query;
    
    if (!q || q.length < 2) {
      return res.json({ suggestions: [] });
    }
    
    const suggestions = [];
    
    // Game suggestions
    if (type === 'all' || type === 'games') {
      const gameResult = await dbClient.query(`
        SELECT DISTINCT unnest(games) as game, COUNT(*) as coach_count
        FROM coaches 
        WHERE status = 'verified' 
          AND EXISTS (
            SELECT 1 FROM unnest(games) g WHERE g ILIKE $1
          )
        GROUP BY game
        ORDER BY coach_count DESC
        LIMIT 5
      `, [`%${q}%`]);
      
      gameResult.rows.forEach(row => {
        suggestions.push({
          type: 'game',
          value: row.game,
          count: row.coach_count,
          display: `${row.game} (${row.coach_count} coaches)`
        });
      });
    }
    
    // Language suggestions
    if (type === 'all' || type === 'languages') {
      const langResult = await dbClient.query(`
        SELECT DISTINCT unnest(languages) as language, COUNT(*) as coach_count
        FROM coaches 
        WHERE status = 'verified' 
          AND EXISTS (
            SELECT 1 FROM unnest(languages) l WHERE l ILIKE $1
          )
        GROUP BY language
        ORDER BY coach_count DESC
        LIMIT 3
      `, [`%${q}%`]);
      
      langResult.rows.forEach(row => {
        suggestions.push({
          type: 'language',
          value: row.language,
          count: row.coach_count,
          display: `${row.language} (${row.coach_count} coaches)`
        });
      });
    }
    
    // Coach name suggestions
    if (type === 'all' || type === 'coaches') {
      const coachResult = await dbClient.query(`
        SELECT display_name, COUNT(*) OVER() as total_matches
        FROM coaches 
        WHERE status = 'verified' 
          AND display_name ILIKE $1
        ORDER BY display_name
        LIMIT 3
      `, [`%${q}%`]);
      
      coachResult.rows.forEach(row => {
        suggestions.push({
          type: 'coach',
          value: row.display_name,
          display: row.display_name
        });
      });
    }
    
    res.json({ 
      suggestions: suggestions.slice(0, 8), // Limit total suggestions
      query: q
    });
  } catch (error) {
    console.error('Get suggestions error:', error);
    res.status(500).json({ error: 'Failed to get suggestions' });
  }
});

// Get search filters/facets
app.get('/search/filters', async (req, res) => {
  try {
    // Get available games
    const gamesResult = await dbClient.query(`
      SELECT DISTINCT unnest(games) as game, COUNT(*) as count
      FROM coaches 
      WHERE status = 'verified'
      GROUP BY game
      ORDER BY count DESC, game
      LIMIT 20
    `);
    
    // Get available languages
    const languagesResult = await dbClient.query(`
      SELECT DISTINCT unnest(languages) as language, COUNT(*) as count
      FROM coaches 
      WHERE status = 'verified'
      GROUP BY language
      ORDER BY count DESC, language
      LIMIT 10
    `);
    
    // Get price ranges
    const priceResult = await dbClient.query(`
      SELECT 
        MIN(hourly_rate) as min_rate,
        MAX(hourly_rate) as max_rate,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY hourly_rate) as q1,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hourly_rate) as median,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY hourly_rate) as q3
      FROM coaches 
      WHERE status = 'verified' AND hourly_rate IS NOT NULL
    `);
    
    // Get rating distribution
    const ratingResult = await dbClient.query(`
      SELECT 
        FLOOR(AVG(r.score)) as rating_level,
        COUNT(DISTINCT c.id) as coach_count
      FROM coaches c
      JOIN bookings b ON c.id = b.coach_id
      JOIN ratings r ON b.id = r.booking_id
      WHERE c.status = 'verified'
      GROUP BY FLOOR(AVG(r.score))
      ORDER BY rating_level DESC
    `);
    
    res.json({
      games: gamesResult.rows,
      languages: languagesResult.rows,
      priceRange: priceResult.rows[0] || {
        min_rate: 0,
        max_rate: 100,
        q1: 25,
        median: 50,
        q3: 75
      },
      ratingLevels: ratingResult.rows
    });
  } catch (error) {
    console.error('Get filters error:', error);
    res.status(500).json({ error: 'Failed to get search filters' });
  }
});

// Index coach for search (called when coach profile is updated)
app.post('/index/coach/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    // Get coach data
    const result = await dbClient.query(`
      SELECT 
        c.*,
        u.email,
        COALESCE(AVG(r.score), 0) as average_rating,
        COUNT(r.score) as total_reviews
      FROM coaches c 
      JOIN users u ON c.user_id = u.id 
      LEFT JOIN bookings b ON c.id = b.coach_id
      LEFT JOIN ratings r ON b.id = r.booking_id
      WHERE c.id = $1
      GROUP BY c.id, u.email
    `, [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Coach not found' });
    }
    
    const coach = result.rows[0];
    
    // Index in Elasticsearch (mock)
    await esClient.index({
      index: 'coaches',
      id: coach.id,
      body: {
        display_name: coach.display_name,
        bio: coach.bio,
        games: coach.games,
        languages: coach.languages,
        hourly_rate: coach.hourly_rate,
        average_rating: coach.average_rating,
        total_reviews: coach.total_reviews,
        status: coach.status,
        created_at: coach.created_at
      }
    });
    
    console.log('Coach indexed for search:', { coachId: id });
    
    res.json({ message: 'Coach indexed successfully', coachId: id });
  } catch (error) {
    console.error('Index coach error:', error);
    res.status(500).json({ error: 'Failed to index coach' });
  }
});

// Popular searches
app.get('/search/popular', (req, res) => {
  try {
    const popularSearches = [
      { query: 'League of Legends', count: 156 },
      { query: 'Counter-Strike', count: 89 },
      { query: 'Valorant', count: 67 },
      { query: 'Dota 2', count: 45 },
      { query: 'Overwatch', count: 34 },
      { query: 'Fortnite', count: 28 },
      { query: 'Apex Legends', count: 22 },
      { query: 'Rocket League', count: 18 }
    ];
    
    res.json({ 
      popularSearches: popularSearches.slice(0, 6),
      period: 'last_30_days'
    });
  } catch (error) {
    console.error('Get popular searches error:', error);
    res.status(500).json({ error: 'Failed to get popular searches' });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Search Service running on port ${PORT}`);
  console.log('Coach search and discovery ready');
});

module.exports = app;