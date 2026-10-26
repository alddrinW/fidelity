-- El mensaje de bienvenida ("¡Bienvenido a Fidelity!") sale solo la primera vez
-- que una persona entra a su cuenta. Se guarda en el servidor para que no vuelva
-- a salir al iniciar sesión de nuevo ni desde otro dispositivo.
--
-- Las cuentas que ya existían antes de este cambio ya usaron la app: se crean
-- con la bienvenida "vista" (DEFAULT TRUE al agregar la columna) y, a partir de
-- ahí, las cuentas nuevas empiezan sin verla (DEFAULT FALSE).

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS has_seen_welcome BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE public.profiles
    ALTER COLUMN has_seen_welcome SET DEFAULT FALSE;
