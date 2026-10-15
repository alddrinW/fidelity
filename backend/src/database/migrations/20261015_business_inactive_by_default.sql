-- Los negocios nuevos nacen inactivos hasta que el administrador valida el pago
-- del registro. Solo cambia el valor por defecto: los negocios que ya existen
-- conservan su estado actual (no se desactiva ninguno).
ALTER TABLE public.businesses ALTER COLUMN is_active SET DEFAULT FALSE;
