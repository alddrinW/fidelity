-- Minijuegos: permiso por negocio (lo aprueba el administrador) y retos enviados.
-- Idempotente. Con DB_SYNCHRONIZE=true TypeORM crea esto solo.
CREATE TABLE IF NOT EXISTS public.game_access (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    note VARCHAR(300),
    admin_note VARCHAR(300),
    games TEXT,
    prize_type VARCHAR(20),
    prize_value INT,
    prize_label VARCHAR(120),
    prize_campaigns JSONB,
    requested_at TIMESTAMP NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    resolved_by_id UUID,
    CONSTRAINT uq_game_access_business UNIQUE (business_id)
);

CREATE TABLE IF NOT EXISTS public.game_invites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    sent_by_id UUID,
    game VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'sent',
    result VARCHAR(10),
    score INT,
    state JSONB,
    claim_id UUID,
    expires_at TIMESTAMPTZ NOT NULL,
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_game_invites_user_created
    ON public.game_invites (user_id, created_at);
