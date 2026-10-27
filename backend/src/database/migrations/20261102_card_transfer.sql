-- Tarjetas en venta: además de PayPhone, el cliente puede pagar por transferencia
-- (a las cuentas de Fidelity) y subir el comprobante; el administrador lo revisa y,
-- al aprobarlo, el cliente recibe su tarjeta.

ALTER TABLE public.card_purchases
    ADD COLUMN IF NOT EXISTS method VARCHAR(10) NOT NULL DEFAULT 'payphone',
    ADD COLUMN IF NOT EXISTS proof_url TEXT,
    ADD COLUMN IF NOT EXISTS transfer_note VARCHAR(200),
    ADD COLUMN IF NOT EXISTS reported_at TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS review_note VARCHAR(300),
    ADD COLUMN IF NOT EXISTS reviewed_by_id UUID,
    ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMP WITH TIME ZONE;

-- Las transferencias por revisar, para el panel del administrador.
CREATE INDEX IF NOT EXISTS idx_card_purchases_review
    ON public.card_purchases (status, reported_at)
    WHERE method = 'transfer';
