const express = require('express');
const { Client } = require('pg');
const helmet = require('helmet');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');

const app = express();
const PORT = process.env.PORT || 3006;

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
    service: 'messaging-service',
    timestamp: new Date().toISOString()
  });
});

// Send message
app.post('/messages', async (req, res) => {
  try {
    const { bookingId, senderId, content, messageType = 'text' } = req.body;
    
    if (!bookingId || !senderId || !content) {
      return res.status(400).json({ 
        error: 'Booking ID, sender ID, and content are required' 
      });
    }

    const messageId = uuidv4();
    
    const result = await dbClient.query(`
      INSERT INTO messages (id, booking_id, sender_id, content, message_type) 
      VALUES ($1, $2, $3, $4, $5) 
      RETURNING *
    `, [messageId, bookingId, senderId, content, messageType]);

    const message = result.rows[0];
    
    // Emit real-time event (placeholder for Socket.IO)
    console.log('MessageSent event:', { messageId, bookingId, senderId });

    res.status(201).json(message);
  } catch (error) {
    console.error('Send message error:', error);
    res.status(500).json({ error: 'Failed to send message' });
  }
});

// Get messages for a booking
app.get('/bookings/:bookingId/messages', async (req, res) => {
  try {
    const { bookingId } = req.params;
    const { limit = 50, offset = 0 } = req.query;
    
    const result = await dbClient.query(`
      SELECT m.*, u.email as sender_email
      FROM messages m
      JOIN users u ON m.sender_id = u.id
      WHERE m.booking_id = $1
      ORDER BY m.created_at DESC
      LIMIT $2 OFFSET $3
    `, [bookingId, parseInt(limit), parseInt(offset)]);

    res.json({
      messages: result.rows.reverse(), // Show oldest first
      pagination: {
        limit: parseInt(limit),
        offset: parseInt(offset),
        total: result.rows.length
      }
    });
  } catch (error) {
    console.error('Get messages error:', error);
    res.status(500).json({ error: 'Failed to get messages' });
  }
});

// Mark messages as read
app.put('/messages/read', async (req, res) => {
  try {
    const { bookingId, userId } = req.body;
    
    if (!bookingId || !userId) {
      return res.status(400).json({ error: 'Booking ID and User ID are required' });
    }

    // Mark messages as read (would need a read_status table in production)
    console.log('Messages marked as read:', { bookingId, userId });

    res.json({ message: 'Messages marked as read' });
  } catch (error) {
    console.error('Mark messages read error:', error);
    res.status(500).json({ error: 'Failed to mark messages as read' });
  }
});

// Send notification
app.post('/notifications', async (req, res) => {
  try {
    const { userId, type, title, message, data = {} } = req.body;
    
    if (!userId || !type || !message) {
      return res.status(400).json({ 
        error: 'User ID, type, and message are required' 
      });
    }

    const notification = {
      id: uuidv4(),
      userId,
      type, // 'booking_reminder', 'session_started', 'payment_received', etc.
      title,
      message,
      data,
      sent: new Date().toISOString(),
      status: 'sent'
    };

    // Send push notification (placeholder for actual implementation)
    console.log('Notification sent:', notification);

    res.status(201).json(notification);
  } catch (error) {
    console.error('Send notification error:', error);
    res.status(500).json({ error: 'Failed to send notification' });
  }
});

// WebSocket endpoint info
app.get('/websocket', (req, res) => {
  res.json({ 
    message: 'WebSocket endpoint for real-time messaging',
    endpoint: 'ws://localhost:3006/socket.io',
    events: [
      'message_sent',
      'user_typing',
      'user_joined',
      'user_left'
    ]
  });
});

// Typing indicator
app.post('/typing', (req, res) => {
  try {
    const { bookingId, userId, isTyping } = req.body;
    
    if (!bookingId || !userId) {
      return res.status(400).json({ error: 'Booking ID and User ID are required' });
    }

    // Emit typing event (placeholder for Socket.IO)
    console.log('Typing event:', { bookingId, userId, isTyping });

    res.json({ message: 'Typing status updated' });
  } catch (error) {
    console.error('Typing indicator error:', error);
    res.status(500).json({ error: 'Failed to update typing status' });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Messaging Service running on port ${PORT}`);
  console.log('Real-time messaging and notifications ready');
});

module.exports = app;