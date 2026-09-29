"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppDataSource = void 0;
const typeorm_1 = require("typeorm");
const dotenv = require("dotenv");
const entities_1 = require("../database/entities");
dotenv.config();
exports.AppDataSource = new typeorm_1.DataSource({
    type: 'postgres',
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT, 10) || 5432,
    username: process.env.DB_USERNAME || 'postgres',
    password: process.env.DB_PASSWORD || 'postgres',
    database: process.env.DB_DATABASE || 'fidelity_db',
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
    synchronize: process.env.DB_SYNCHRONIZE === 'true',
    logging: process.env.NODE_ENV === 'development',
    entities: [
        entities_1.Profile,
        entities_1.BusinessCategory,
        entities_1.Business,
        entities_1.LoyaltyCard,
        entities_1.QrCode,
        entities_1.Scan,
        entities_1.ScanAttempt,
        entities_1.Reward,
        entities_1.RewardTransferHistory,
        entities_1.SupportTicket,
    ],
    migrations: [__dirname + '/../database/migrations/*{.ts,.js}'],
});
//# sourceMappingURL=data-source.js.map