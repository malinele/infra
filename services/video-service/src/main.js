const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');

const app = express();
const PORT = process.env.PORT || 3005;

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'video-service',
    timestamp: new Date().toISOString()
  });
});

// Generate session token for WebRTC
app.post('/sessions/:id/token', (req, res) => {
  try {
    const { id } = req.params;
    const { userId, role = 'participant' } = req.body;
    
    if (!userId) {
      return res.status(400).json({ error: 'User ID is required' });
    }

    // Mock SFU token generation (replace with actual Janus/mediasoup implementation)
    const token = {
      sessionId: id,
      userId,
      role,
      token: `sfu_token_${uuidv4()}`,
      expires: new Date(Date.now() + 2 * 60 * 60 * 1000), // 2 hours
      
      // TURN/STUN configuration
      iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
        {
          urls: 'turn:turnserver.example.com:3478',
          username: 'user',
          credential: 'pass'
        }
      ],
      
      // SFU connection details
      sfu: {
        url: 'ws://localhost:8080/video',
        room: `session_${id}`
      }
    };

    console.log('Video session token generated:', { sessionId: id, userId, role });

    res.json(token);
  } catch (error) {
    console.error('Generate token error:', error);
    res.status(500).json({ error: 'Failed to generate session token' });
  }
});

// Create video room
app.post('/rooms', (req, res) => {
  try {
    const { sessionId, settings = {} } = req.body;
    
    if (!sessionId) {
      return res.status(400).json({ error: 'Session ID is required' });
    }

    const room = {
      id: `room_${uuidv4()}`,
      sessionId,
      settings: {
        maxParticipants: settings.maxParticipants || 2,
        recordingEnabled: settings.recordingEnabled || false,
        screenShareEnabled: settings.screenShareEnabled || true,
        ...settings
      },
      participants: [],
      created: new Date().toISOString(),
      status: 'active'
    };

    console.log('Video room created:', room);

    res.status(201).json(room);
  } catch (error) {
    console.error('Create room error:', error);
    res.status(500).json({ error: 'Failed to create video room' });
  }
});

// Get room info
app.get('/rooms/:id', (req, res) => {
  try {
    const { id } = req.params;
    
    // Mock room data (replace with actual room state)
    const room = {
      id,
      sessionId: 'mock-session-id',
      participants: [
        { userId: 'user1', role: 'coach', joinedAt: new Date().toISOString() },
        { userId: 'user2', role: 'student', joinedAt: new Date().toISOString() }
      ],
      settings: {
        maxParticipants: 2,
        recordingEnabled: false,
        screenShareEnabled: true
      },
      status: 'active'
    };

    res.json(room);
  } catch (error) {
    console.error('Get room error:', error);
    res.status(500).json({ error: 'Failed to get room info' });
  }
});

// Start recording
app.post('/recordings/start', (req, res) => {
  try {
    const { sessionId, roomId } = req.body;
    
    if (!sessionId || !roomId) {
      return res.status(400).json({ error: 'Session ID and Room ID are required' });
    }

    const recording = {
      id: `rec_${uuidv4()}`,
      sessionId,
      roomId,
      started: new Date().toISOString(),
      status: 'recording',
      format: 'webm'
    };

    console.log('Recording started:', recording);

    res.status(201).json(recording);
  } catch (error) {
    console.error('Start recording error:', error);
    res.status(500).json({ error: 'Failed to start recording' });
  }
});

// Stop recording
app.post('/recordings/:id/stop', (req, res) => {
  try {
    const { id } = req.params;
    
    const recording = {
      id,
      status: 'completed',
      stopped: new Date().toISOString(),
      duration: 3600, // seconds
      fileSize: 1024 * 1024 * 100, // 100MB
      objectKey: `recordings/${id}.webm`
    };

    console.log('Recording stopped:', recording);

    res.json(recording);
  } catch (error) {
    console.error('Stop recording error:', error);
    res.status(500).json({ error: 'Failed to stop recording' });
  }
});

// WebSocket endpoint for real-time video signaling (placeholder)
app.get('/ws', (req, res) => {
  res.json({ 
    message: 'WebSocket endpoint for video signaling',
    upgrade: 'Use WebSocket protocol to connect'
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Video Service running on port ${PORT}`);
  console.log('WebRTC SFU management ready');
});

module.exports = app;