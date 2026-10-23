-- Cumpleaños: la fecha de nacimiento de cada usuario (opcional) y el registro
-- de a qué dueños ya se les avisó y a quién ya se le regaló una gift card.

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS birth_date DATE;

CREATE TABLE IF NOT EXISTS public.birthday_notices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    year INT NOT NULL,
    notified_at TIMESTAMP WITH TIME ZONE,
    gifted_at TIMESTAMP WITH TIME ZONE,
    gift_campaign_id UUID,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_birthday_notice UNIQUE (business_id, user_id, year)
);

-- Para encontrar rápido a quienes cumplen años en una fecha.
CREATE INDEX IF NOT EXISTS idx_profiles_birth_md
    ON public.profiles (EXTRACT(MONTH FROM birth_date), EXTRACT(DAY FROM birth_date))
    WHERE birth_date IS NOT NULL;

-- Las gift cards de cumpleaños se crean con una plantilla propia.
ALTER TABLE public.campaigns
    ADD COLUMN IF NOT EXISTS template VARCHAR(20);
