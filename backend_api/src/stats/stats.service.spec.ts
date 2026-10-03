import { DataSource } from 'typeorm';
import { createMemoryDataSource } from '../../test/memory-data-source.js';
import { TEST_DATABASE_URL, resetPostgres } from '../../test/postgres-test-db.js';
import { dataSourceOptions } from '../database/data-source-options.js';
import { GeminiCall } from './gemini-call.entity.js';
import { StatsService, vnDay } from './stats.service.js';
import { UsageDaily } from './usage-daily.entity.js';

// 2026-10-03 16:30 UTC = 23:30 giờ Việt Nam.
const LATE_EVENING_VN = Date.UTC(2026, 9, 3, 16, 30);

describe('vnDay', () => {
  it('counts days in Vietnam time (UTC+7), not in the server clock', () => {
    expect(vnDay(LATE_EVENING_VN)).toBe('2026-10-03');
    expect(vnDay(LATE_EVENING_VN + 30 * 60_000)).toBe('2026-10-04'); // 00:00 giờ Việt Nam = 17:00 UTC
  });
});

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

describe.each(targets)('StatsService (%s)', (_name, open) => {
  let dataSource: DataSource;
  let now: number;
  let stats: StatsService;
  const usage = () =>
    dataSource
      .getRepository(UsageDaily)
      .find({ order: { day: 'ASC', metric: 'ASC' } })
      .then((rows) => rows.map((row) => ({ day: row.day, metric: row.metric, count: row.count, total_ms: Number(row.total_ms) })));

  beforeEach(async () => {
    dataSource = await open();
    now = LATE_EVENING_VN;
    stats = new StatsService(dataSource, () => now);
  });

  afterEach(async () => {
    if (dataSource.isInitialized) await dataSource.destroy();
  });

  it('adds up one row per day and metric, with the total time', async () => {
    await stats.count('plan.gemini', 15_200);
    await stats.count('plan.gemini', 9_800.4);
    await stats.count('plan.sample');
    now += 60 * 60_000; // sang ngày mới theo giờ Việt Nam
    await stats.count('plan.gemini', 12_000);
    expect(await usage()).toEqual([
      { day: '2026-10-03', metric: 'plan.gemini', count: 2, total_ms: 25_000 },
      { day: '2026-10-03', metric: 'plan.sample', count: 1, total_ms: 0 },
      { day: '2026-10-04', metric: 'plan.gemini', count: 1, total_ms: 12_000 },
    ]);
  });

  it('counts every concurrent request (atomic upsert)', async () => {
    await Promise.all(Array.from({ length: 10 }, () => stats.count('meal_swap.pool')));
    expect(await usage()).toEqual([{ day: '2026-10-03', metric: 'meal_swap.pool', count: 10, total_ms: 0 }]);
  });

  it('logs one Gemini call per row, dated in Vietnam time', async () => {
    await stats.recordGeminiCall({
      task: 'plan',
      model: 'gemini-3.5-flash',
      attempt: 1,
      outcome: 'overloaded',
      httpStatus: 503,
      durationMs: 20_412.6,
      message: '503 UNAVAILABLE — This model is currently experiencing high demand.',
    });
    await stats.recordGeminiCall({ task: 'plan', model: 'gemini-3.6-flash', attempt: 2, outcome: 'ok', durationMs: 17_480 });
    const rows = await dataSource.getRepository(GeminiCall).find({ order: { id: 'ASC' } });
    expect(rows.map(({ day, task, model, attempt, outcome, http_status, duration_ms, message }) => ({
      day, task, model, attempt, outcome, http_status, duration_ms, message,
    }))).toEqual([
      {
        day: '2026-10-03',
        task: 'plan',
        model: 'gemini-3.5-flash',
        attempt: 1,
        outcome: 'overloaded',
        http_status: 503,
        duration_ms: 20_413,
        message: '503 UNAVAILABLE — This model is currently experiencing high demand.',
      },
      { day: '2026-10-03', task: 'plan', model: 'gemini-3.6-flash', attempt: 2, outcome: 'ok', http_status: null, duration_ms: 17_480, message: null },
    ]);
    expect(rows[0].created_at.getTime()).toBe(LATE_EVENING_VN);
  });

  it('never fails the request when the database is down — the numbers just miss one entry', async () => {
    await dataSource.destroy();
    await expect(stats.count('plan.gemini', 1)).resolves.toBeUndefined();
    await expect(
      stats.recordGeminiCall({ task: 'plan', model: 'gemini-3.5-flash', attempt: 1, outcome: 'ok', durationMs: 1 }),
    ).resolves.toBeUndefined();
  });
});
