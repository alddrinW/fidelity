-- Pago con tarjeta por PayPhone: datos de la transaccion en la pasarela.
-- Idempotente. Con DB_SYNCHRONIZE=true TypeORM crea las columnas solo.
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS gateway_client_tx_id VARCHAR(20);
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS gateway_pay_url VARCHAR(300);
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS gateway_transaction_id VARCHAR(40);
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS gateway_auth_code VARCHAR(40);

CREATE UNIQUE INDEX IF NOT EXISTS uq_payments_gateway_client_tx_id
    ON public.payments (gateway_client_tx_id);

-- Ajustes editables por el administrador (precios del registro).
CREATE TABLE IF NOT EXISTS public.app_settings (
    key VARCHAR(60) PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);
