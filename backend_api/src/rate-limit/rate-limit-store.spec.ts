import { DataSource } from 'typeorm';
import { createMemoryDataSource } from '../../test/memory-data-source.js';
import { TEST_DATABASE_URL, resetPostgres } from '../../test/postgres-test-db.js';
import { dataSourceOptions } from '../database/data-source-options.js';
import { RateLimitStore } from './rate-limit-store.js';

const TEN_MINUTES = 600_000;

// Cùng một bộ test cho SQLite (máy dev, test) và Postgres (production — chạy khi có TEST_DATABASE_URL).
const targets: [string, () => Promise<DataSource>][] = [['SQLite', createMemoryDataSource]];
if (TEST_DATABASE_URL) {
  targets.push([
    'Postgres',
    async () => {
      await resetPostgres(TEST_DATABASE_URL);
      return new DataSource(dataSourceOptions({ kind: 'postgres', url: TEST_DATABASE_URL })).initialize();
    },
  ]);
}

describe.each(targets)('RateLimitStore (%s)', (_name, open) => {
  let dataSource: DataSource;
  let now: number;
  let storage: RateLimitStore;

  beforeEach(async () => {
    dataSource = await open();
    now = 1_790_000_000_000;
    storage = new RateLimitStore(dataSource, () => now);
  });

  afterEach(async () => {
    await dataSource.destroy();
  });

  it('đếm trong một cửa sổ; vượt hạn mức → chặn tới hết cửa sổ', async () => {
    expect(await storage.increment('a', TEN_MINUTES, 2)).toEqual({
      totalHits: 1,
      timeToExpire: 600,
      isBlocked: false,
    });
    now += 60_000;
    expect((await storage.increment('a', TEN_MINUTES, 2)).isBlocked).toBe(false);
    now += 60_000;
    expect(await storage.increment('a', TEN_MINUTES, 2)).toEqual({
      totalHits: 3,
      timeToExpire: 480,
      isBlocked: true,
    });
  });

  it('hết cửa sổ → đếm lại từ 1', async () => {
    for (let i = 0; i < 3; i++) await storage.increment('a', TEN_MINUTES, 2);
    now += TEN_MINUTES;
    expect(await storage.increment('a', TEN_MINUTES, 2)).toMatchObject({
      totalHits: 1,
      isBlocked: false,
      timeToExpire: 600,
    });
  });

  it('mỗi khoá đếm riêng', async () => {
    for (let i = 0; i < 3; i++) await storage.increment('a', TEN_MINUTES, 2);
    expect((await storage.increment('b', TEN_MINUTES, 2)).totalHits).toBe(1);
  });

  it('nhiều request cùng lúc vẫn đếm đủ (cộng dồn nguyên tử)', async () => {
    await Promise.all(
      Array.from({ length: 10 }, () => storage.increment('a', TEN_MINUTES, 100)),
    );
    expect((await storage.increment('a', TEN_MINUTES, 100)).totalHits).toBe(11);
  });

  it('mở cửa sổ mới thì xoá các khoá đã hết hạn hơn một ngày', async () => {
    await storage.increment('cu', TEN_MINUTES, 2);
    now += 2 * 86_400_000;
    await storage.increment('moi', TEN_MINUTES, 2);
    const rows: { key: string }[] = await dataSource.query('SELECT "key" FROM rate_limits');
    expect(rows.map((row) => row.key)).toEqual(['moi']);
  });
});
