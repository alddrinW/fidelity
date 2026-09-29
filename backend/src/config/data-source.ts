import { DataSource } from 'typeorm';
import * as dotenv from 'dotenv';
import {
  Profile,
  BusinessCategory,
  Business,
  LoyaltyCard,
  QrCode,
  Scan,
  ScanAttempt,
  Reward,
  RewardTransferHistory,
  SupportTicket,
} from '../database/entities';

dotenv.config();

export const AppDataSource = new DataSource({
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
    Profile,
    BusinessCategory,
    Business,
    LoyaltyCard,
    QrCode,
    Scan,
    ScanAttempt,
    Reward,
    RewardTransferHistory,
    SupportTicket,
  ],
  migrations: [__dirname + '/../database/migrations/*{.ts,.js}'],
});
