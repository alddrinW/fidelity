-- Invitar amigos: quien invita gana sus puntos cuando se juntan los amigos que
-- pide el administrador (3 por defecto), no con cada amigo.

-- Cuándo cada amigo contó para la meta de quien lo invitó.
ALTER TABLE public.referrals
    ADD COLUMN IF NOT EXISTS counted_at TIMESTAMP WITH TIME ZONE;

-- Cuántos grupos de amigos ya se le pagaron a cada persona.
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS referral_groups_paid INT NOT NULL DEFAULT 0;

-- Los amigos que ya pagaron con la regla anterior (por su primer escaneo) quedan
-- contados, y esos grupos como pagados: nadie cobra dos veces lo mismo.
UPDATE public.referrals
   SET counted_at = rewarded_at
 WHERE status = 'rewarded' AND counted_at IS NULL;

UPDATE public.profiles p
   SET referral_groups_paid = sub.groups
  FROM (
        SELECT referrer_id, FLOOR(COUNT(*) / 3.0)::INT AS groups
          FROM public.referrals
         WHERE counted_at IS NOT NULL
         GROUP BY referrer_id
       ) sub
 WHERE p.id = sub.referrer_id;
