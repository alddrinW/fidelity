-- Los premios de los minijuegos son campañas internas: no se muestran al dueño.
ALTER TABLE public.campaigns ADD COLUMN IF NOT EXISTS hidden BOOLEAN NOT NULL DEFAULT FALSE;

UPDATE public.campaigns
   SET hidden = TRUE
 WHERE description = 'Premio de los minijuegos' AND type = 'gift_card';
