import pg from 'pg';
import { DataSource } from 'typeorm';
import { createMemoryDataSource } from '../../test/memory-data-source.js';
import { TEST_DATABASE_URL, resetPostgres } from '../../test/postgres-test-db.js';
import { dataSourceOptions, resolveDatabaseTarget } from './data-source-options.js';

describe('database migrations (SQLite — máy dev, test)', () => {
  let dataSource: DataSource;

  beforeEach(async () => {
    dataSource = await createMemoryDataSource();
  });

  afterEach(async () => {
    if (dataSource.isInitialized) await dataSource.destroy();
  });

  // Sửa entity mà quên viết migration → test này in ra đúng câu SQL còn thiếu.
  it('creates exactly the schema the entities describe', async () => {
    const { upQueries } = await dataSource.driver.createSchemaBuilder().log();
    expect(upQueries.map((query) => query.query)).toEqual([]);
  });

  it('enforces foreign keys, so deleting a user deletes their plans', async () => {
    expect(await dataSource.query('PRAGMA foreign_keys')).toEqual([{ foreign_keys: 1 }]);
  });

  it('reverts cleanly', async () => {
    for (let i = 0; i < dataSource.migrations.length; i++) await dataSource.undoLastMigration();
    const tables = await dataSource.query(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('users', 'plan_records', 'rate_limits')",
    );
    expect(tables).toEqual([]);
  });
});

// Production (Neon). Chạy khi có TEST_DATABASE_URL — CI luôn có (service container Postgres).
describe.skipIf(!TEST_DATABASE_URL)('database migrations (Postgres — production)', () => {
  let dataSource: DataSource;

  beforeEach(async () => {
    await resetPostgres(TEST_DATABASE_URL);
    dataSource = await new DataSource(dataSourceOptions({ kind: 'postgres', url: TEST_DATABASE_URL })).initialize();
  });

  afterEach(async () => {
    if (dataSource.isInitialized) await dataSource.destroy();
  });

  it('creates exactly the schema the entities describe', async () => {
    const { upQueries } = await dataSource.driver.createSchemaBuilder().log();
    expect(upQueries.map((query) => query.query)).toEqual([]);
  });

  it('deleting a user deletes their plans (ON DELETE CASCADE)', async () => {
    const [{ id }] = await dataSource.query(
      "INSERT INTO users (google_sub, email, name) VALUES ('mock:a@b.co', 'a@b.co', 'a') RETURNING id",
    );
    await dataSource.query(
      "INSERT INTO plan_records (id, user_id, target_calories, plan_json, created_at) VALUES ($1, $2, 1800, '{}', now())",
      ['00000000-0000-4000-8000-000000000009', id],
    );
    await dataSource.query('DELETE FROM users WHERE id = $1', [id]);
    expect(await dataSource.query('SELECT id FROM plan_records')).toEqual([]);
  });

  it('reverts cleanly', async () => {
    for (let i = 0; i < dataSource.migrations.length; i++) await dataSource.undoLastMigration();
    const tables = await dataSource.query(
      "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' " +
        "AND table_name IN ('users', 'plan_records', 'rate_limits')",
    );
    expect(tables).toEqual([]);
  });
});

describe('resolveDatabaseTarget', () => {
  it('DATABASE_URL → Postgres; không có → SQLite (DATABASE_PATH hoặc database.sqlite)', () => {
    expect(resolveDatabaseTarget({ DATABASE_URL: ' postgresql://u:p@h/db ' })).toEqual({
      kind: 'postgres',
      url: 'postgresql://u:p@h/db',
    });
    expect(resolveDatabaseTarget({ DATABASE_PATH: '/data/x.sqlite' })).toEqual({ kind: 'sqlite', path: '/data/x.sqlite' });
    expect(resolveDatabaseTarget({})).toEqual({ kind: 'sqlite', path: 'database.sqlite' });
  });

  it('chuỗi kết nối không phải Postgres → không khởi động', () => {
    expect(() => resolveDatabaseTarget({ DATABASE_URL: 'mysql://h/db' })).toThrow(/Postgres/);
  });

  it('trên Vercel mà thiếu DATABASE_URL → không khởi động (SQLite sẽ mất dữ liệu, #11)', () => {
    expect(() => resolveDatabaseTarget({ VERCEL: '1', DATABASE_PATH: 'x.sqlite' })).toThrow(/DATABASE_URL/);
    expect(resolveDatabaseTarget({ VERCEL: '1', DATABASE_URL: 'postgres://h/db' }).kind).toBe('postgres');
  });

  it('Postgres dùng module pg import tĩnh (Vercel chỉ đóng gói module được import tĩnh)', () => {
    expect(dataSourceOptions({ kind: 'postgres', url: 'postgres://h/db' })).toMatchObject({ driver: pg });
  });
});
