-- Banners del inicio del cliente que sube el administrador: imagen ya diseñada,
-- a dónde lleva al tocarla, orden, y un horario opcional.

CREATE TABLE IF NOT EXISTS public.banners (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title         VARCHAR(80) NOT NULL,
    image_url     TEXT NOT NULL,
    image_url_en  TEXT,
    action        VARCHAR(20) NOT NULL DEFAULT 'none',
    link_url      TEXT,
    blend_white   BOOLEAN NOT NULL DEFAULT TRUE,
    position      INTEGER NOT NULL DEFAULT 0,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    starts_at     TIMESTAMPTZ,
    ends_at       TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_banners_action CHECK (action IN ('none', 'invite', 'weekly_game', 'offers', 'scan', 'link'))
);

CREATE INDEX IF NOT EXISTS idx_banners_active_position
    ON public.banners (is_active, position);
