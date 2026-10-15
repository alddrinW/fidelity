-- Fidelity PostgreSQL Initial Schema Migration

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Profiles (Usuarios)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) NOT NULL UNIQUE,
    full_name VARCHAR(150),
    role VARCHAR(20) NOT NULL DEFAULT 'client' CHECK (role IN ('admin', 'business', 'client', 'approver')),
    password_hash VARCHAR(255),
    fcm_token TEXT,
    avatar_url TEXT,
    phone VARCHAR(50),
    is_demo BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- 2. Business Categories
CREATE TABLE IF NOT EXISTS public.business_categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    icon VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Seed basic categories
INSERT INTO public.business_categories (name, icon)
VALUES 
    ('Cafeterías & Panaderías', 'coffee'),
    ('Restaurantes & Bares', 'restaurant'),
    ('Belleza & Barberías', 'content_cut'),
    ('Moda & Calzado', 'checkroom'),
    ('Salud & Fitness', 'fitness_center'),
    ('Servicios & Entretenimiento', 'local_activity')
ON CONFLICT (name) DO NOTHING;

-- 3. Businesses
CREATE TABLE IF NOT EXISTS public.businesses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    category_id INT REFERENCES public.business_categories(id) ON DELETE SET NULL,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    category VARCHAR(100),
    logo_url TEXT,
    reward_description TEXT NOT NULL DEFAULT 'Premio Fidelity por puntos completados',
    reward_long_description TEXT,
    points_required INT NOT NULL DEFAULT 10,
    cooldown_hours INT NOT NULL DEFAULT 24,
    -- Nace inactivo: el admin lo activa al validar el pago del registro.
    is_active BOOLEAN NOT NULL DEFAULT FALSE,
    latitude DECIMAL(10, 7),
    longitude DECIMAL(10, 7),
    address TEXT,
    phone VARCHAR(50),
    tax_id VARCHAR(13),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- 4. Loyalty Cards
CREATE TABLE IF NOT EXISTS public.loyalty_cards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    current_points INT NOT NULL DEFAULT 0,
    total_points_lifetime INT NOT NULL DEFAULT 0,
    rewards_claimed INT NOT NULL DEFAULT 0,
    last_scan_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_user_business_card UNIQUE (user_id, business_id)
);

-- 5. QR Codes
CREATE TABLE IF NOT EXISTS public.qr_codes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    qr_code VARCHAR(255) NOT NULL UNIQUE,
    label VARCHAR(100),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- 6. Scans
CREATE TABLE IF NOT EXISTS public.scans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    loyalty_card_id UUID NOT NULL REFERENCES public.loyalty_cards(id) ON DELETE CASCADE,
    qr_code_id UUID REFERENCES public.qr_codes(id) ON DELETE SET NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'approved' CHECK (status IN ('pending', 'approved', 'rejected')),
    is_demo BOOLEAN NOT NULL DEFAULT FALSE,
    scanned_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- 7. Scan Attempts
CREATE TABLE IF NOT EXISTS public.scan_attempts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    business_id UUID REFERENCES public.businesses(id) ON DELETE SET NULL,
    qr_code_id UUID REFERENCES public.qr_codes(id) ON DELETE SET NULL,
    success BOOLEAN NOT NULL DEFAULT FALSE,
    failure_reason VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- 8. Rewards
CREATE TABLE IF NOT EXISTS public.rewards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    loyalty_card_id UUID NOT NULL REFERENCES public.loyalty_cards(id) ON DELETE CASCADE,
    reward_description TEXT,
    description TEXT,
    points_used INT NOT NULL DEFAULT 10,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'claimed', 'rejected')),
    is_demo BOOLEAN NOT NULL DEFAULT FALSE,
    earned_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    claimed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- 9. Reward Transfer History
CREATE TABLE IF NOT EXISTS public.reward_transfer_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reward_id UUID NOT NULL REFERENCES public.rewards(id) ON DELETE CASCADE,
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    from_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    to_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    transferred_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- 10. Support Tickets
CREATE TABLE IF NOT EXISTS public.support_tickets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    business_id UUID REFERENCES public.businesses(id) ON DELETE SET NULL,
    subject VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'open',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Indexes for high-performance lookups
CREATE INDEX IF NOT EXISTS idx_loyalty_cards_user ON public.loyalty_cards(user_id);
CREATE INDEX IF NOT EXISTS idx_loyalty_cards_business ON public.loyalty_cards(business_id);
CREATE INDEX IF NOT EXISTS idx_scans_user ON public.scans(user_id);
CREATE INDEX IF NOT EXISTS idx_scans_business ON public.scans(business_id);
CREATE INDEX IF NOT EXISTS idx_rewards_user ON public.rewards(user_id);
CREATE INDEX IF NOT EXISTS idx_rewards_business ON public.rewards(business_id);
CREATE INDEX IF NOT EXISTS idx_qr_codes_code ON public.qr_codes(qr_code);
