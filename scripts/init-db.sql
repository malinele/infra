-- Initialize database for Esport Coach Connect

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    auth_provider_id VARCHAR(255),
    preferences JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Coaches table
CREATE TABLE coaches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    display_name VARCHAR(255) NOT NULL,
    bio TEXT,
    languages TEXT[] DEFAULT ARRAY[]::TEXT[],
    games TEXT[] DEFAULT ARRAY[]::TEXT[],
    hourly_rate DECIMAL(10,2),
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'verified', 'suspended')),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Availability table
CREATE TABLE availability (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    coach_id UUID REFERENCES coaches(id) ON DELETE CASCADE,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    is_recurring BOOLEAN DEFAULT FALSE,
    timezone VARCHAR(50) DEFAULT 'UTC',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Bookings table
CREATE TABLE bookings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    player_id UUID REFERENCES users(id),
    coach_id UUID REFERENCES coaches(id),
    starts_at TIMESTAMPTZ NOT NULL,
    duration INTERVAL NOT NULL,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'in_progress', 'completed', 'cancelled')),
    timezone VARCHAR(50) DEFAULT 'UTC',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Payment intents table
CREATE TABLE payment_intents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID REFERENCES bookings(id),
    provider VARCHAR(50) NOT NULL,
    status VARCHAR(20) DEFAULT 'requires_action' CHECK (status IN ('requires_action', 'authorized', 'captured', 'refunded')),
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    provider_intent_id VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Ratings table
CREATE TABLE ratings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID REFERENCES bookings(id),
    score SMALLINT CHECK (score >= 1 AND score <= 5),
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Messages table
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID REFERENCES bookings(id),
    sender_id UUID REFERENCES users(id),
    content TEXT NOT NULL,
    message_type VARCHAR(20) DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'file')),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Recordings table
CREATE TABLE recordings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID REFERENCES bookings(id),
    object_key VARCHAR(500) NOT NULL,
    size_bytes BIGINT,
    duration_seconds INTEGER,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Events outbox for reliable messaging
CREATE TABLE outbox_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    aggregate_id UUID NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    event_data JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMPTZ,
    version INTEGER DEFAULT 1
);

-- Indexes for performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_coaches_user_id ON coaches(user_id);
CREATE INDEX idx_coaches_status ON coaches(status);
CREATE INDEX idx_availability_coach_id ON availability(coach_id);
CREATE INDEX idx_availability_time_range ON availability(start_time, end_time);
CREATE INDEX idx_bookings_player_id ON bookings(player_id);
CREATE INDEX idx_bookings_coach_id ON bookings(coach_id);
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_bookings_starts_at ON bookings(starts_at);
CREATE INDEX idx_payment_intents_booking_id ON payment_intents(booking_id);
CREATE INDEX idx_messages_booking_id ON messages(booking_id);
CREATE INDEX idx_outbox_events_processed ON outbox_events(processed_at) WHERE processed_at IS NULL;

-- Seed data
INSERT INTO users (id, email, auth_provider_id) VALUES
    ('550e8400-e29b-41d4-a716-446655440001', 'coach@example.com', 'auth0|coach1'),
    ('550e8400-e29b-41d4-a716-446655440002', 'player@example.com', 'auth0|player1');

INSERT INTO coaches (user_id, display_name, bio, games, hourly_rate, status) VALUES
    ('550e8400-e29b-41d4-a716-446655440001', 'Pro Coach', 'Professional esports coach with 5+ years experience', ARRAY['League of Legends', 'Counter-Strike'], 50.00, 'verified');

-- Database initialization completed successfully
SELECT 'Database initialized successfully' AS initialization_status;