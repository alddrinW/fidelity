"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.configuration = void 0;
const configuration = () => ({
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
    webhookSecret: process.env.WEBHOOK_SECRET || 'fidelity_webhook_secure_secret_2026',
});
exports.configuration = configuration;
//# sourceMappingURL=configuration.js.map