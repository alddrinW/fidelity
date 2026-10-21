-- Retos de escaneos: una campaña que da un premio al hacer N escaneos.
ALTER TABLE public.campaigns
    ADD COLUMN IF NOT EXISTS required_scans INT;
