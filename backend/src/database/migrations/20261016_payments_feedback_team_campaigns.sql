-- Pagos de registro (PAGA YA), opiniones, equipo (rol Aprobador), sucursales y
-- campañas. Idempotente: se puede ejecutar mas de una vez. Con
-- DB_SYNCHRONIZE=true TypeORM crea todo esto solo; este script es para
-- entornos donde no.

-- Rol Aprobador (la restriccion original solo permitia admin, business y client).
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles
    ADD CONSTRAINT profiles_role_check CHECK (role IN ('admin', 'business', 'client', 'approver'));

-- Sucursales: un negocio puede colgar de un negocio principal del mismo dueño.
ALTER TABLE public.businesses
    ADD COLUMN IF NOT EXISTS parent_id UUID REFERENCES public.businesses(id) ON DELETE SET NULL;

-- Ordenes de pago del registro de negocios y sucursales.
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    concept VARCHAR(20) NOT NULL DEFAULT 'registration',
    amount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    reference VARCHAR(20) NOT NULL UNIQUE,
    method VARCHAR(20),
    note VARCHAR(200),
    proof_url TEXT,
    admin_note VARCHAR(300),
    receipt_number VARCHAR(30) UNIQUE,
    validated_by_id UUID,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    reported_at TIMESTAMPTZ,
    paid_at TIMESTAMPTZ
);

-- Sugerencias, reclamos y felicitaciones de los clientes.
CREATE TABLE IF NOT EXISTS public.feedbacks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    kind VARCHAR(20) NOT NULL DEFAULT 'suggestion',
    rating SMALLINT,
    tags TEXT[] NOT NULL DEFAULT '{}',
    message TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'open',
    reply TEXT,
    resolved_by_id UUID,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ
);

-- Equipo de un negocio (aprobadores asignados por el dueño).
CREATE TABLE IF NOT EXISTS public.business_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL DEFAULT 'approver',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_business_member UNIQUE (business_id, user_id)
);

-- Campañas: eventos, tarjetas de regalo y rutas (pasaporte).
CREATE TABLE IF NOT EXISTS public.campaigns (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL,
    title VARCHAR(120) NOT NULL,
    description TEXT,
    image_url TEXT,
    benefit_type VARCHAR(20),
    benefit_value INT,
    benefit_label VARCHAR(120),
    required_stamps INT,
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    notified_at TIMESTAMPTZ,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.campaign_businesses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    campaign_id UUID NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    CONSTRAINT uq_campaign_business UNIQUE (campaign_id, business_id)
);

CREATE TABLE IF NOT EXISTS public.campaign_claims (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    campaign_id UUID NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    code VARCHAR(20) NOT NULL UNIQUE,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    source VARCHAR(20) NOT NULL DEFAULT 'claim',
    redeemed_by_id UUID,
    redeemed_at TIMESTAMPTZ,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_campaign_claim_user UNIQUE (campaign_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.campaign_stamps (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    campaign_id UUID NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    scan_id UUID,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_campaign_stamp UNIQUE (campaign_id, user_id, business_id)
);

CREATE INDEX IF NOT EXISTS idx_payments_status ON public.payments (status);
CREATE INDEX IF NOT EXISTS idx_feedbacks_business ON public.feedbacks (business_id, status);
CREATE INDEX IF NOT EXISTS idx_campaigns_starts ON public.campaigns (starts_at);
