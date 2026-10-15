-- Recuperacion de contrasena por codigo enviado al correo.
-- Idempotente. Con DB_SYNCHRONIZE=true TypeORM crea las columnas solo.
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS reset_code_hash VARCHAR(100);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS reset_code_expires_at TIMESTAMPTZ;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS reset_attempts INT NOT NULL DEFAULT 0;
