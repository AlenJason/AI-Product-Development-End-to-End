import type { ConfigService } from '@nestjs/config';
import type { DataSourceOptions } from 'typeorm';
import { PlanRecord } from './entities/plan-record.entity.js';
import { User } from './entities/user.entity.js';
import { InitialSchema1790208000000 } from './migrations/1790208000000-initial-schema.js';
import { FeedbackReceipt } from './entities/feedback-receipt.entity.js';
import { FeedbackReceipts1793498400000 } from './migrations/1793498400000-feedback-receipts.js';
import { UserPasswords1794000000000 } from './migrations/1794000000000-user-passwords.js';

export const DEFAULT_DATABASE_PATH = 'database.sqlite';
const ENTITIES = [User, PlanRecord, FeedbackReceipt];

// Dùng chung cho DatabaseModule và test. Không bao giờ bật `synchronize` cho SQLite: TypeORM có thể xoá cột
// và dữ liệu khi entity đổi. Đổi entity = viết migration mới.
export function dataSourceOptions(database: string): DataSourceOptions {
  return {
    type: 'better-sqlite3',
    database,
    entities: ENTITIES,
    migrations: [
      InitialSchema1790208000000,
      FeedbackReceipts1793498400000,
      UserPasswords1794000000000,
    ],
    migrationsRun: true,
    synchronize: false,
  };
}

/** Chọn cấu hình MySQL hoặc SQLite dựa theo biến môi trường DB_TYPE. */
export function resolveDataSourceOptions(config: ConfigService): DataSourceOptions {
  const dbType = config.get<string>('DB_TYPE')?.trim().toLowerCase();
  if (dbType === 'mysql') {
    return {
      type: 'mysql',
      host: config.get<string>('DB_HOST')?.trim() || 'localhost',
      port: Number(config.get<string>('DB_PORT')) || 3306,
      username: config.get<string>('DB_USERNAME')?.trim() || 'root',
      password: config.get<string>('DB_PASSWORD') ?? '',
      database: config.get<string>('DB_DATABASE')?.trim() || 'smartfit_db',
      entities: ENTITIES,
      synchronize: true,
      bigNumberStrings: false,
      charset: 'utf8mb4',
    };
  }
  return dataSourceOptions(
    config.get<string>('DATABASE_PATH')?.trim() || DEFAULT_DATABASE_PATH,
  );
}
