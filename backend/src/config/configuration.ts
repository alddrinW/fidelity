export interface BankAccountConfig {
  name: string;
  accountNumber: string;
  accountType: string;
  holder: string;
  taxId: string;
}

/**
 * Lee las cuentas bancarias de `BANK_ACCOUNTS`, una lista en JSON:
 * `[{"name":"Banco","accountNumber":"123","accountType":"Ahorros","holder":"Titular","taxId":"110..."}]`.
 * Ignora las entradas sin número de cuenta; un JSON inválido da una lista vacía.
 */
export function parseBankAccounts(raw?: string): BankAccountConfig[] {
  if (!raw || !raw.trim()) return [];
  try {
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed
      .filter((a) => a && typeof a.accountNumber === 'string' && a.accountNumber.trim())
      .map((a) => ({
        name: String(a.name ?? '').trim(),
        accountNumber: String(a.accountNumber).trim(),
        accountType: String(a.accountType ?? '').trim(),
        holder: String(a.holder ?? '').trim(),
        taxId: String(a.taxId ?? '').trim(),
      }));
  } catch {
    return [];
  }
}

export const configuration = () => ({
  port: parseInt(process.env.PORT, 10) || 3000,
  nodeEnv: process.env.NODE_ENV || 'development',
  apiPrefix: process.env.API_PREFIX || 'api/v1',
  corsOrigin: process.env.CORS_ORIGIN || '*',
  database: {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT, 10) || 5432,
    username: process.env.DB_USERNAME || 'postgres',
    password: process.env.DB_PASSWORD || 'postgres',
    database: process.env.DB_DATABASE || 'fidelity_db',
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
    synchronize: process.env.DB_SYNCHRONIZE === 'true',
  },
  jwt: {
    secret: process.env.JWT_SECRET || 'super_secret_jwt_key_fidelity_2026_change_in_production',
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  },
  firebase: {
    serviceAccount: process.env.FIREBASE_SERVICE_ACCOUNT || '',
    credentialsPath: process.env.FIREBASE_CREDENTIALS_PATH || '',
  },
  // Precios del registro. Son valores de ejemplo: define los reales con
  // REGISTRATION_FEE y BRANCH_FEE en el .env.
  payments: {
    registrationFee: parseFloat(process.env.REGISTRATION_FEE) || 20,
    branchFee: parseFloat(process.env.BRANCH_FEE) || 10,
    currency: process.env.PAYMENT_CURRENCY || 'USD',
    // Cuentas bancarias para transferencias y depósitos (BANK_ACCOUNTS es una
    // lista en JSON). Sin cuentas, la app no ofrece el pago por transferencia.
    bankAccounts: parseBankAccounts(process.env.BANK_ACCOUNTS),
    // Pago con tarjeta por PayPhone (botón por redirección). Sin token, tienda
    // y URL pública del backend, la app no ofrece el pago con tarjeta.
    payphone: {
      token: process.env.PAYPHONE_TOKEN || '',
      storeId: process.env.PAYPHONE_STORE_ID || '',
      apiUrl: process.env.PAYPHONE_API_URL || 'https://pay.payphonetodoesposible.com',
      // Dirección del backend alcanzable desde el navegador del cliente: a ella
      // vuelve PayPhone tras el pago (p. ej. https://api.midominio.com).
      publicApiUrl: (process.env.PUBLIC_API_URL || '').replace(/\/+$/, ''),
    },
  },
  // Correo saliente (recuperación de contraseña). Sin SMTP_HOST el código se
  // escribe en el log del servidor, solo fuera de producción.
  mail: {
    host: process.env.SMTP_HOST || '',
    port: parseInt(process.env.SMTP_PORT, 10) || 587,
    user: process.env.SMTP_USER || '',
    // Las contraseñas de aplicación de Google se copian con espacios: se quitan.
    pass: (process.env.SMTP_PASS || '').replace(/\s+/g, ''),
    // Puerto 465 = TLS directo; los demás usan STARTTLS. SMTP_SECURE lo fuerza.
    secure: process.env.SMTP_SECURE ? process.env.SMTP_SECURE === 'true' : undefined,
    // Solo para probar con un servidor local sin cifrado: SMTP_REQUIRE_TLS=false.
    requireTls: process.env.SMTP_REQUIRE_TLS !== 'false',
    from: process.env.MAIL_FROM || (process.env.SMTP_USER ? `Fidelity <${process.env.SMTP_USER}>` : 'Fidelity <no-reply@fidelity.app>'),
  },
  // Límite de intentos (inicio de sesión, recuperar contraseña...). Detrás de un
  // proxy o balanceador define TRUST_PROXY=1 para ver la IP real del cliente.
  rateLimit: {
    disabled: process.env.NODE_ENV === 'test' || process.env.RATE_LIMIT_DISABLED === 'true',
    trustProxy: process.env.TRUST_PROXY || '',
  },
  webhookSecret: process.env.WEBHOOK_SECRET || 'fidelity_webhook_secure_secret_2026',
});
