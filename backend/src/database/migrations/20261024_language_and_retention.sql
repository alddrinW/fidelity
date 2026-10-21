-- Idioma de cada usuario (los avisos del servidor salen en él) e índices por
-- fecha para la limpieza automática de avisos, intentos de escaneo y retos.

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS language VARCHAR(5) NOT NULL DEFAULT 'es';

CREATE INDEX IF NOT EXISTS idx_notifications_created ON public.notifications (created_at);
CREATE INDEX IF NOT EXISTS idx_scan_attempts_created ON public.scan_attempts (created_at);
CREATE INDEX IF NOT EXISTS idx_game_invites_expires ON public.game_invites (expires_at);
