-- Agrega la cedula/RUC del propietario y la descripcion larga del premio.
-- Idempotente: se puede ejecutar mas de una vez. Con DB_SYNCHRONIZE=true
-- TypeORM crea estas columnas solo; este script es para entornos donde no.
ALTER TABLE public.businesses
    ADD COLUMN IF NOT EXISTS tax_id VARCHAR(13),
    ADD COLUMN IF NOT EXISTS reward_long_description TEXT;
