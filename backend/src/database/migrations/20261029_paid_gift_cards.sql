-- Tarjetas en venta: una gift card puede tener precio. El cliente la compra
-- con tarjeta (PayPhone), Fidelity retiene una comisión y el resto se le paga
-- al local cuando el cliente canjea la tarjeta.

-- La oferta: precio (en centavos), cupos y cuántos días vale la tarjeta tras comprarla.
ALTER TABLE public.campaigns
    ADD COLUMN IF NOT EXISTS price_cents INT,
    ADD COLUMN IF NOT EXISTS stock INT,
    ADD COLUMN IF NOT EXISTS card_valid_days INT;

-- Una tarjeta comprada vence a los N días (no con la campaña).
ALTER TABLE public.campaign_claims
    ADD COLUMN IF NOT EXISTS expires_at TIMESTAMP WITH TIME ZONE;

-- Cada compra: el cobro de PayPhone, la comisión y el pago al local.
CREATE TABLE IF NOT EXISTS public.card_purchases (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    campaign_id UUID NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    amount_cents INT NOT NULL,
    commission_cents INT NOT NULL DEFAULT 0,
    status VARCHAR(12) NOT NULL DEFAULT 'pending',
    reference VARCHAR(12) NOT NULL UNIQUE,
    gateway_client_tx_id VARCHAR(20) NOT NULL UNIQUE,
    gateway_pay_url VARCHAR(300),
    gateway_transaction_id VARCHAR(40),
    gateway_auth_code VARCHAR(40),
    claim_id UUID REFERENCES public.campaign_claims(id) ON DELETE SET NULL,
    reserved_until TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    paid_at TIMESTAMP WITH TIME ZONE,
    settled_at TIMESTAMP WITH TIME ZONE,
    settled_by_id UUID,
    settlement_note VARCHAR(200)
);

CREATE INDEX IF NOT EXISTS idx_card_purchases_campaign ON public.card_purchases (campaign_id, status);
CREATE INDEX IF NOT EXISTS idx_card_purchases_user ON public.card_purchases (user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_card_purchases_business ON public.card_purchases (business_id, status);
