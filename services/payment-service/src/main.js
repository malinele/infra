const express = require('express');
const { Client } = require('pg');
const helmet = require('helmet');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');

const app = express();
const PORT = process.env.PORT || 3007;

// Mock Stripe integration (replace with actual Stripe when ready)
const mockStripe = {
  paymentIntents: {
    create: async (params) => ({
      id: `pi_mock_${Date.now()}`,
      client_secret: `pi_mock_${Date.now()}_secret`,
      status: 'requires_payment_method',
      amount: params.amount,
      currency: params.currency
    }),
    confirm: async (id) => ({
      id,
      status: 'succeeded'
    }),
    capture: async (id) => ({
      id,
      status: 'succeeded'
    })
  }
};

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
    service: 'payment-service',
    timestamp: new Date().toISOString()
  });
});

// Create payment intent (escrow)
app.post('/payment-intents', async (req, res) => {
  try {
    const { 
      bookingId, 
      amount, 
      currency = 'USD', 
      paymentMethodId 
    } = req.body;
    
    if (!bookingId || !amount) {
      return res.status(400).json({ 
        error: 'Booking ID and amount are required' 
      });
    }

    // Create payment intent with Stripe (mock)
    const intent = await mockStripe.paymentIntents.create({
      amount: Math.round(amount * 100), // Convert to cents
      currency: currency.toLowerCase(),
      capture_method: 'manual', // Hold funds until session starts
      metadata: { bookingId }
    });

    const paymentId = uuidv4();
    
    // Store in database
    const result = await dbClient.query(`
      INSERT INTO payment_intents 
      (id, booking_id, provider, status, amount, currency, provider_intent_id) 
      VALUES ($1, $2, $3, $4, $5, $6, $7) 
      RETURNING *
    `, [paymentId, bookingId, 'stripe', 'requires_action', amount, currency, intent.id]);

    res.status(201).json({
      paymentIntentId: paymentId,
      clientSecret: intent.client_secret,
      status: intent.status,
      payment: result.rows[0]
    });
  } catch (error) {
    console.error('Create payment intent error:', error);
    res.status(500).json({ error: 'Failed to create payment intent' });
  }
});

// Confirm payment (authorize)
app.post('/payment-intents/:id/confirm', async (req, res) => {
  try {
    const { id } = req.params;
    
    // Get payment intent from database
    const paymentResult = await dbClient.query(
      'SELECT * FROM payment_intents WHERE id = $1',
      [id]
    );

    if (paymentResult.rows.length === 0) {
      return res.status(404).json({ error: 'Payment intent not found' });
    }

    const payment = paymentResult.rows[0];
    
    // Confirm with Stripe (mock)
    const intent = await mockStripe.paymentIntents.confirm(payment.provider_intent_id);
    
    // Update status
    await dbClient.query(`
      UPDATE payment_intents 
      SET status = 'authorized', updated_at = CURRENT_TIMESTAMP 
      WHERE id = $1
    `, [id]);

    // Emit event
    console.log('PaymentAuthorized event:', { paymentId: id, bookingId: payment.booking_id });

    res.json({
      status: intent.status,
      message: 'Payment authorized successfully'
    });
  } catch (error) {
    console.error('Confirm payment error:', error);
    res.status(500).json({ error: 'Failed to confirm payment' });
  }
});

// Capture payment (when session starts)
app.post('/payment-intents/:id/capture', async (req, res) => {
  try {
    const { id } = req.params;
    
    const paymentResult = await dbClient.query(
      'SELECT * FROM payment_intents WHERE id = $1',
      [id]
    );

    if (paymentResult.rows.length === 0) {
      return res.status(404).json({ error: 'Payment intent not found' });
    }

    const payment = paymentResult.rows[0];
    
    if (payment.status !== 'authorized') {
      return res.status(400).json({ 
        error: 'Payment must be authorized before capture' 
      });
    }

    // Capture with Stripe (mock)
    const intent = await mockStripe.paymentIntents.capture(payment.provider_intent_id);
    
    // Update status
    await dbClient.query(`
      UPDATE payment_intents 
      SET status = 'captured', updated_at = CURRENT_TIMESTAMP 
      WHERE id = $1
    `, [id]);

    // Emit event
    console.log('PaymentCaptured event:', { 
      paymentId: id, 
      bookingId: payment.booking_id,
      amount: payment.amount 
    });

    res.json({
      status: intent.status,
      message: 'Payment captured successfully'
    });
  } catch (error) {
    console.error('Capture payment error:', error);
    res.status(500).json({ error: 'Failed to capture payment' });
  }
});

// Refund payment
app.post('/payment-intents/:id/refund', async (req, res) => {
  try {
    const { id } = req.params;
    const { amount, reason } = req.body;
    
    const paymentResult = await dbClient.query(
      'SELECT * FROM payment_intents WHERE id = $1',
      [id]
    );

    if (paymentResult.rows.length === 0) {
      return res.status(404).json({ error: 'Payment intent not found' });
    }

    const payment = paymentResult.rows[0];
    
    if (payment.status !== 'captured') {
      return res.status(400).json({ 
        error: 'Only captured payments can be refunded' 
      });
    }

    // Process refund (mock)
    const refundAmount = amount || payment.amount;
    
    // Update status
    await dbClient.query(`
      UPDATE payment_intents 
      SET status = 'refunded', updated_at = CURRENT_TIMESTAMP 
      WHERE id = $1
    `, [id]);

    // Emit event
    console.log('PaymentRefunded event:', { 
      paymentId: id, 
      bookingId: payment.booking_id,
      refundAmount,
      reason 
    });

    res.json({
      message: 'Refund processed successfully',
      refundAmount
    });
  } catch (error) {
    console.error('Refund payment error:', error);
    res.status(500).json({ error: 'Failed to process refund' });
  }
});

// Get payment status
app.get('/payment-intents/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await dbClient.query(`
      SELECT pi.*, b.starts_at, b.status as booking_status
      FROM payment_intents pi
      JOIN bookings b ON pi.booking_id = b.id
      WHERE pi.id = $1
    `, [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Payment intent not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Get payment error:', error);
    res.status(500).json({ error: 'Failed to get payment' });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Payment Service running on port ${PORT}`);
});

module.exports = app;