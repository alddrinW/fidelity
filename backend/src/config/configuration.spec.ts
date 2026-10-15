import { parseBankAccounts } from './configuration';

describe('parseBankAccounts', () => {
  const account = {
    name: 'Banco de Loja',
    accountNumber: ' 2900000001 ',
    accountType: 'Cuenta de ahorros',
    holder: 'Titular Uno',
    taxId: '1100000001',
  };

  it('lee una lista de cuentas y limpia los espacios', () => {
    const accounts = parseBankAccounts(JSON.stringify([account, { ...account, accountNumber: '2' }]));

    expect(accounts).toHaveLength(2);
    expect(accounts[0].accountNumber).toBe('2900000001');
    expect(accounts[1].accountNumber).toBe('2');
  });

  it('completa con vacio los datos que faltan', () => {
    const [one] = parseBankAccounts(JSON.stringify([{ accountNumber: '123' }]));

    expect(one).toEqual({ name: '', accountNumber: '123', accountType: '', holder: '', taxId: '' });
  });

  it('ignora las entradas sin numero de cuenta', () => {
    expect(parseBankAccounts(JSON.stringify([{ name: 'X' }, null, { accountNumber: '  ' }]))).toEqual([]);
  });

  it.each([undefined, '', '   ', 'no es json', '{"accountNumber":"1"}', '42'])(
    'un valor invalido (%p) da una lista vacia',
    (raw) => {
      expect(parseBankAccounts(raw as string)).toEqual([]);
    },
  );
});
