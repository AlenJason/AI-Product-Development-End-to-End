// Chạy migration lên DB của DATABASE_URL (Postgres) hoặc DATABASE_PATH (SQLite), từ bản build (dist/).
// Vercel gọi ở bước build; lúc chạy đặt DATABASE_RUN_MIGRATIONS=false để nhiều instance không chạy chồng (P20).
// Không in chuỗi kết nối — nó chứa mật khẩu DB.
import 'reflect-metadata';
import { DataSource } from 'typeorm';
import { dataSourceOptions, resolveDatabaseTarget } from '../dist/database/data-source-options.js';

const target = resolveDatabaseTarget(process.env);
const dataSource = new DataSource(dataSourceOptions(target, { migrationsRun: false }));
await dataSource.initialize();
try {
  const ran = await dataSource.runMigrations({ transaction: 'all' });
  const where = target.kind === 'postgres' ? 'Postgres' : `SQLite (${target.path})`;
  console.log(ran.length ? `${where}: đã chạy ${ran.map((m) => m.name).join(', ')}` : `${where}: không có migration mới`);
} finally {
  await dataSource.destroy();
}
