import pg from 'pg';
import type { DataSourceOptions } from 'typeorm';
import { PlanRecord } from './entities/plan-record.entity.js';
import { User } from './entities/user.entity.js';
import { InitialSchema1790208000000 } from './migrations/1790208000000-initial-schema.js';
import { RateLimits1791158400000 } from './migrations/1791158400000-rate-limits.js';
import { InitialSchemaPostgres1791072000000 } from './migrations/postgres/1791072000000-initial-schema-postgres.js';
import { RateLimitsPostgres1791158400000 } from './migrations/postgres/1791158400000-rate-limits-postgres.js';
import { RateLimitCounter } from '../rate-limit/rate-limit-counter.entity.js';

export const DEFAULT_DATABASE_PATH = 'database.sqlite';

// Hai loại DB (giai đoạn 9, quyết định Q5): Postgres khi có DATABASE_URL (production — Neon), SQLite khi không
// (máy dev, test). Mỗi loại một bộ migration; migrations.spec.ts kiểm cả hai khớp entity.
export type DatabaseTarget = { kind: 'sqlite'; path: string } | { kind: 'postgres'; url: string };

export interface DatabaseEnv {
  DATABASE_URL?: string;
  DATABASE_PATH?: string;
  // Vercel tự đặt VERCEL=1 khi build và khi chạy.
  VERCEL?: string;
}

export function resolveDatabaseTarget(env: DatabaseEnv): DatabaseTarget {
  const url = env.DATABASE_URL?.trim();
  if (url) {
    if (!/^postgres(ql)?:\/\//.test(url)) {
      throw new Error('DATABASE_URL phải là chuỗi kết nối Postgres (postgres://… hoặc postgresql://…).');
    }
    return { kind: 'postgres', url };
  }
  // Vercel không có ổ bền: file SQLite nằm trong thư mục tạm của từng instance, mất khi instance tắt (#11).
  if (env.VERCEL) throw new Error('Trên Vercel cần DATABASE_URL (Postgres) — SQLite sẽ mất dữ liệu.');
  return { kind: 'sqlite', path: env.DATABASE_PATH?.trim() || DEFAULT_DATABASE_PATH };
}

// Dùng chung cho DatabaseModule, script migrate và test. Không bao giờ bật `synchronize`: TypeORM có thể xoá
// cột và dữ liệu khi entity đổi. Đổi entity = viết migration mới cho CẢ HAI loại DB.
export function dataSourceOptions(target: DatabaseTarget, { migrationsRun = true } = {}): DataSourceOptions {
  const common = { entities: [User, PlanRecord, RateLimitCounter], migrationsRun, synchronize: false };
  if (target.kind === 'postgres') {
    return {
      ...common,
      type: 'postgres',
      url: target.url,
      // Truyền thẳng module `pg`: TypeORM tự nạp bằng require động, Vercel không thấy nên không đóng gói `pg` vào
      // function ("Postgres package has not been found installed" khi deploy thử, giai đoạn 9).
      driver: pg,
      migrations: [InitialSchemaPostgres1791072000000, RateLimitsPostgres1791158400000],
      // gen_random_uuid() có sẵn từ Postgres 13 — không cần CREATE EXTENSION (Neon không cho mọi extension).
      uuidExtension: 'pgcrypto',
      installExtensions: false,
    };
  }
  return { ...common, type: 'better-sqlite3', database: target.path, migrations: [InitialSchema1790208000000, RateLimits1791158400000] };
}
