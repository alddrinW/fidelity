-- Gift cards: a quien le llegan (todos los clientes o los elegidos).
-- Idempotente. Con DB_SYNCHRONIZE=true TypeORM crea esto solo.
ALTER TABLE public.campaigns ADD COLUMN IF NOT EXISTS audience VARCHAR(10) NOT NULL DEFAULT 'all';

CREATE TABLE IF NOT EXISTS public.campaign_recipients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    campaign_id UUID NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    CONSTRAINT uq_campaign_recipient UNIQUE (campaign_id, user_id)
);
