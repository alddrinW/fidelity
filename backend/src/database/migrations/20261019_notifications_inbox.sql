-- Bandeja de notificaciones de cada usuario (todos sus movimientos).
-- Idempotente. Con DB_SYNCHRONIZE=true TypeORM crea la tabla solo.
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    type VARCHAR(40) NOT NULL DEFAULT 'general',
    title VARCHAR(160) NOT NULL,
    body TEXT NOT NULL,
    data JSONB,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_created
    ON public.notifications (user_id, created_at);
