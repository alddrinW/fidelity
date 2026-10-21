-- Minijuegos: el dueño fija desde cuándo y hasta cuándo se puede jugar, y cada
-- cliente tiene hasta 3 intentos para ganar.

ALTER TABLE public.game_invites
    ADD COLUMN IF NOT EXISTS starts_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS notified_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS attempts INT NOT NULL DEFAULT 0;

-- Los retos que ya existían empezaban al enviarse, ya estaban avisados y los
-- que se habían jugado cuentan como un intento.
UPDATE public.game_invites
   SET starts_at = created_at,
       notified_at = created_at,
       attempts = CASE WHEN status IN ('playing', 'finished') THEN 1 ELSE 0 END
 WHERE starts_at IS NULL;

ALTER TABLE public.game_invites ALTER COLUMN starts_at SET NOT NULL;
ALTER TABLE public.game_invites ALTER COLUMN starts_at SET DEFAULT NOW();
