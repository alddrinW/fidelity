-- Juego semanal: una vez por semana (de lunes a domingo, hora de Ecuador) cada
-- cliente elige un negocio y juega; si gana, suma puntos ahí. No puede repetir
-- un negocio donde ya ganó. Reutiliza los juegos (game_invites).

ALTER TABLE public.game_invites
    ADD COLUMN IF NOT EXISTS weekly BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS week_start DATE;

-- Como máximo un juego semanal por cliente y semana.
CREATE UNIQUE INDEX IF NOT EXISTS uq_game_invites_weekly
    ON public.game_invites (user_id, week_start)
    WHERE weekly = TRUE;
