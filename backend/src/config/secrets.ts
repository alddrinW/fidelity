/** Los valores de ejemplo: si el servidor real los usa, cualquiera puede falsificar sesiones. */
const KNOWN_DEFAULTS = [
  'super_secret_jwt_key_fidelity_2026_change_in_production',
  'fidelity_webhook_secure_secret_2026',
];

/**
 * Qué claves del servidor no son seguras para producción. Una lista vacía
 * significa que todo está bien. Fuera de producción no se exige nada (para
 * poder trabajar con los valores de ejemplo).
 */
export function insecureSecrets(env: Record<string, string | undefined>): string[] {
  if (env.NODE_ENV !== 'production') return [];

  const problems: string[] = [];
  const jwt = env.JWT_SECRET ?? '';
  if (!jwt) {
    problems.push('JWT_SECRET no está definido');
  } else if (KNOWN_DEFAULTS.includes(jwt) || /change_in_production/i.test(jwt)) {
    problems.push('JWT_SECRET sigue siendo el valor de ejemplo');
  } else if (jwt.length < 32) {
    problems.push('JWT_SECRET es demasiado corto (mínimo 32 caracteres)');
  }

  const webhook = env.WEBHOOK_SECRET ?? '';
  if (webhook && KNOWN_DEFAULTS.includes(webhook)) {
    problems.push('WEBHOOK_SECRET sigue siendo el valor de ejemplo');
  }

  if ((env.DB_PASSWORD ?? '') === 'postgres') {
    problems.push('DB_PASSWORD es la clave por defecto de Postgres');
  }
  return problems;
}

/** Detiene el arranque en producción si hay claves inseguras (mejor que salir con una puerta abierta). */
export function assertProductionSecrets(env: Record<string, string | undefined> = process.env): void {
  const problems = insecureSecrets(env);
  if (problems.length > 0) {
    throw new Error(
      `El servidor no arranca en producción con claves inseguras:\n - ${problems.join('\n - ')}\n` +
        'Cámbialas en el .env (por ejemplo, genera JWT_SECRET con: node -e "console.log(require(\'crypto\').randomBytes(48).toString(\'hex\'))").',
    );
  }
}
