import { BadGatewayException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PayphoneService } from './payphone.service';

describe('PayphoneService', () => {
  const settings: Record<string, any> = {
    'payments.payphone.token': 'tok-123',
    'payments.payphone.storeId': 'store-1',
    'payments.payphone.apiUrl': 'https://pay.example.com',
    'payments.payphone.publicApiUrl': 'https://api.fidelity.test',
    'payments.currency': 'USD',
    apiPrefix: 'api/v1',
  };
  const build = (overrides: Record<string, any> = {}) =>
    new PayphoneService({ get: (k: string) => ({ ...settings, ...overrides })[k] } as ConfigService);

  const reply = (body: unknown, ok = true, status = 200) =>
    jest.fn().mockResolvedValue({ ok, status, json: () => Promise.resolve(body) });

  const realFetch = global.fetch;
  afterEach(() => {
    global.fetch = realFetch;
  });

  it('solo está configurado con token y dirección pública (la tienda es opcional)', () => {
    expect(build().isConfigured()).toBe(true);
    expect(build({ 'payments.payphone.token': '' }).isConfigured()).toBe(false);
    expect(build({ 'payments.payphone.publicApiUrl': '' }).isConfigured()).toBe(false);
    expect(build({ 'payments.payphone.storeId': '' }).isConfigured()).toBe(true);
  });

  it('las direcciones de retorno cuelgan del prefijo de la API', () => {
    const service = build();

    expect(service.returnUrl('return')).toBe(
      'https://api.fidelity.test/api/v1/payments/payphone/return',
    );
    expect(service.returnUrl('cancel')).toBe(
      'https://api.fidelity.test/api/v1/payments/payphone/cancel',
    );
  });

  it('la pasarela propia cuelga del dominio público (el que PayPhone autoriza)', () => {
    expect(build().launchUrl('FID-ABC234-X7K2')).toBe(
      'https://api.fidelity.test/api/v1/payments/payphone/pay/FID-ABC234-X7K2',
    );
  });

  it('solo se redirige a direcciones de PayPhone', () => {
    const service = build();

    expect(service.isPayphoneUrl('https://pay.example.com/Anonymous/Index?paymentId=1')).toBe(true);
    expect(service.isPayphoneUrl('https://evil.example.com/x')).toBe(false);
    expect(service.isPayphoneUrl('http://pay.example.com/x')).toBe(false);
    expect(service.isPayphoneUrl('javascript:alert(1)')).toBe(false);
    expect(service.isPayphoneUrl(null)).toBe(false);
  });

  describe('prepare', () => {
    it('envía el cobro en centavos con el token y las direcciones de retorno', async () => {
      const fetchMock = reply({
        paymentId: 5,
        payWithCard: 'https://pay.example.com/c/5',
        payWithPayPhone: 'https://pay.example.com/p/5',
      });
      global.fetch = fetchMock as any;

      const checkout = await build().prepare({
        amountCents: 2000,
        clientTransactionId: 'FID-ABC234-X7K2',
        reference: 'Fidelity FID-ABC234',
        email: 'ana@mail.com',
      });

      expect(checkout.payWithCard).toBe('https://pay.example.com/c/5');
      const [url, init] = fetchMock.mock.calls[0];
      expect(url).toBe('https://pay.example.com/api/button/Prepare');
      expect(init.headers.Authorization).toBe('Bearer tok-123');
      expect(JSON.parse(init.body)).toMatchObject({
        amount: 2000,
        amountWithoutTax: 2000,
        currency: 'USD',
        storeId: 'store-1',
        clientTransactionId: 'FID-ABC234-X7K2',
        responseUrl: 'https://api.fidelity.test/api/v1/payments/payphone/return',
        cancellationUrl: 'https://api.fidelity.test/api/v1/payments/payphone/cancel',
        email: 'ana@mail.com',
      });
    });

    it('sin Store ID no se envía el campo', async () => {
    const fetchMock = reply({ payWithCard: 'https://x/c', payWithPayPhone: 'https://x/p' });
    global.fetch = fetchMock as any;

    await build({ 'payments.payphone.storeId': '' }).prepare({
      amountCents: 2000,
      clientTransactionId: 'X',
      reference: 'X',
    });

    expect(JSON.parse(fetchMock.mock.calls[0][1].body)).not.toHaveProperty('storeId');
  });

  it('un error de PayPhone no se filtra al cliente', async () => {
      global.fetch = reply({ message: 'token inválido', errorCode: 401 }, false, 401) as any;

      const attempt = build().prepare({
        amountCents: 2000,
        clientTransactionId: 'X',
        reference: 'X',
      });

      await expect(attempt).rejects.toBeInstanceOf(BadGatewayException);
      await expect(attempt).rejects.not.toThrow('token');
    });

    it('una respuesta sin páginas de pago es un error', async () => {
      global.fetch = reply({ paymentId: 5 }) as any;

      await expect(
        build().prepare({ amountCents: 2000, clientTransactionId: 'X', reference: 'X' }),
      ).rejects.toBeInstanceOf(BadGatewayException);
    });

    it('si PayPhone no responde, falla con un error claro', async () => {
      global.fetch = jest.fn().mockRejectedValue(new Error('ECONNREFUSED')) as any;

      await expect(
        build().prepare({ amountCents: 2000, clientTransactionId: 'X', reference: 'X' }),
      ).rejects.toBeInstanceOf(BadGatewayException);
    });
  });

  describe('confirm', () => {
    it('confirma con id y clientTxId (la llave que pide PayPhone)', async () => {
      const fetchMock = reply({ statusCode: 3, transactionStatus: 'Approved', amount: 2000 });
      global.fetch = fetchMock as any;

      const result = await build().confirm(9001, 'FID-ABC234-X7K2');

      expect(result.statusCode).toBe(3);
      const [url, init] = fetchMock.mock.calls[0];
      expect(url).toBe('https://pay.example.com/api/button/V2/Confirm');
      expect(JSON.parse(init.body)).toEqual({ id: 9001, clientTxId: 'FID-ABC234-X7K2' });
    });
  });
});
