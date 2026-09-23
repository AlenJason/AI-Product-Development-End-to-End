import type { DataSourceOptions } from 'typeorm';
import { PlanRecord } from './entities/plan-record.entity.js';
import { User } from './entities/user.entity.js';
import { InitialSchema1790208000000 } from './migrations/1790208000000-initial-schema.js';

export const DEFAULT_DATABASE_PATH = 'database.sqlite';

// Dùng chung cho DatabaseModule và test. Không bao giờ bật `synchronize`: TypeORM có thể xoá cột
// và dữ liệu khi entity đổi. Đổi entity = viết migration mới.
export function dataSourceOptions(database: string): DataSourceOptions {
  return {
    type: 'better-sqlite3',
    database,
    entities: [User, PlanRecord],
    migrations: [InitialSchema1790208000000],
    migrationsRun: true,
    synchronize: false,
  };
}
