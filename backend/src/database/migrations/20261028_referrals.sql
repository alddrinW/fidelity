-- Invitar amigos a la app: cada cliente tiene un código (y un enlace) para
-- invitar a Fidelity. Cuando el amigo hace su primer escaneo aprobado en
-- cualquier local, los dos reciben "puntos de invitación" que usan en el local
-- que elijan entre los que el administrador marcó como participantes.

-- Código de invitación y saldo de puntos de invitación de cada persona.
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS referral_code VARCHAR(12),
    ADD COLUMN IF NOT EXISTS referral_balance INT NOT NULL DEFAULT 0;

CREATE UNIQUE INDEX IF NOT EXISTS uq_profiles_referral_code
    ON public.profiles (referral_code)
    WHERE referral_code IS NOT NULL;

-- Los locales donde se pueden usar los puntos de invitación (los marca el administrador).
ALTER TABLE public.businesses
    ADD COLUMN IF NOT EXISTS referral_enabled BOOLEAN NOT NULL DEFAULT FALSE;

-- Quién invitó a quién. Cada persona solo puede llegar invitada una vez.
CREATE TABLE IF NOT EXISTS public.referrals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    referrer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    referee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status VARCHAR(12) NOT NULL DEFAULT 'pending',
    referrer_points INT NOT NULL DEFAULT 0,
    friend_points INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    rewarded_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT uq_referral_friend UNIQUE (referee_id)
);

CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON public.referrals (referrer_id);

-- En qué local usó cada persona sus puntos de invitación.
CREATE TABLE IF NOT EXISTS public.referral_uses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    points INT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_referral_uses_user ON public.referral_uses (user_id, created_at);
