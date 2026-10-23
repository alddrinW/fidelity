import { assertProductionSecrets, insecureSecrets } from './secrets';

const strong = 'a'.repeat(20) + 'B'.repeat(20) + '1234';

describe('claves del servidor en producción', () => {
  it('fuera de producción no se exige nada (se puede trabajar con los valores de ejemplo)', () => {
    expect(insecureSecrets({ NODE_ENV: 'development' })).toEqual([]);
    expect(insecureSecrets({})).toEqual([]);
    expect(() => assertProductionSecrets({ NODE_ENV: 'development' })).not.toThrow();
  });

  it('en producción sin JWT_SECRET no arranca', () => {
    expect(insecureSecrets({ NODE_ENV: 'production', DB_PASSWORD: 'clave-larga-123' })).toEqual(['JWT_SECRET no está definido']);
  });

  it('en producción con el JWT_SECRET de ejemplo no arranca', () => {
    const problems = insecureSecrets({
      NODE_ENV: 'production',
      JWT_SECRET: 'super_secret_jwt_key_fidelity_2026_change_in_production',
      DB_PASSWORD: 'x1',
    });

    expect(problems).toEqual(['JWT_SECRET sigue siendo el valor de ejemplo']);
  });

  it('un JWT_SECRET corto no sirve', () => {
    expect(insecureSecrets({ NODE_ENV: 'production', JWT_SECRET: 'corta', DB_PASSWORD: 'x1' })).toEqual([
      'JWT_SECRET es demasiado corto (mínimo 32 caracteres)',
    ]);
  });

  it('el secreto del webhook de ejemplo y la clave por defecto de Postgres se señalan', () => {
    const problems = insecureSecrets({
      NODE_ENV: 'production',
      JWT_SECRET: strong,
      WEBHOOK_SECRET: 'fidelity_webhook_secure_secret_2026',
      DB_PASSWORD: 'postgres',
    });

    expect(problems).toEqual(['WEBHOOK_SECRET sigue siendo el valor de ejemplo', 'DB_PASSWORD es la clave por defecto de Postgres']);
  });

  it('con claves propias en producción todo está bien', () => {
    expect(insecureSecrets({ NODE_ENV: 'production', JWT_SECRET: strong, WEBHOOK_SECRET: 'otro-secreto-largo-y-propio', DB_PASSWORD: 'Zx91-clave' })).toEqual([]);
  });

  it('assertProductionSecrets lanza un error que lista todo lo que falta y cómo arreglarlo', () => {
    expect(() => assertProductionSecrets({ NODE_ENV: 'production' })).toThrow(/JWT_SECRET no está definido[\s\S]*randomBytes/);
  });
});
