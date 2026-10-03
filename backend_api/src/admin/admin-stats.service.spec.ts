import { DataSource } from 'typeorm';
import { createMemoryDataSource } from '../../test/memory-data-source.js';
import { TEST_DATABASE_URL, resetPostgres } from '../../test/postgres-test-db.js';
import { dataSourceOptions } from '../database/data-source-options.js';
import type { GeminiService } from '../plan/gemini.service.js';
import { StatsService } from '../stats/stats.service.js';
import { AdminStatsService } from './admin-stats.service.js';

const gemini = {
  isConfigured: true,
  models: { primary: 'gemini-3.5-flash', fallback: 'gemini-3.6-flash' },
  budget: { perCallMs: 45_000, totalMs: 50_000 },
} as unknown as GeminiService;
const rateLimits = { plan: { limit: 5, ttlMs: 600_000 }, adjust: null, admin: { limit: 5, ttlMs: 900_000 }, trustProxyHops: 1 };

// Giờ Việt Nam: 31/08 23:30, 01/09 08:00, 03/10 10:00.
const AUG_31_LATE = Date.UTC(2026, 7, 31, 16, 30);
const SEP_1 = Date.UTC(2026, 8, 1, 1, 0);
const OCT_3 = Date.UTC(2026, 9, 3, 3, 0);

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

describe.each(targets)('AdminStatsService (%s)', (_name, open) => {
  let dataSource: DataSource;
  let now: number;
  let admin: AdminStatsService;

  beforeEach(async () => {
    dataSource = await open();
    const stats = new StatsService(dataSource, () => now);
    for (const at of [AUG_31_LATE, SEP_1, SEP_1, OCT_3]) {
      now = at;
      await stats.count('plan.gemini', 10_000);
      await stats.recordGeminiCall({ task: 'plan', model: 'gemini-3.5-flash', attempt: 1, outcome: 'ok', durationMs: 10_000 });
    }
    now = OCT_3;
    await stats.recordGeminiCall({ task: 'plan', model: 'gemini-3.6-flash', attempt: 2, outcome: 'overloaded', httpStatus: 503, durationMs: 20_000 });
    admin = new AdminStatsService(dataSource, gemini, rateLimits, () => now);
  });

  afterEach(async () => {
    await dataSource.destroy();
  });

  it('adds up months in Vietnam time, newest first', async () => {
    const months = await admin.months();
    expect(months.map((m) => [m.month, m.usage['plan.gemini']])).toEqual([
      ['2026-10', { count: 1, total_ms: 10_000 }],
      ['2026-09', { count: 2, total_ms: 20_000 }],
      ['2026-08', { count: 1, total_ms: 10_000 }],
    ]);
    expect(months[0].gemini).toEqual([
      { model: 'gemini-3.5-flash', outcome: 'ok', calls: 1, avg_ms: 10_000 },
      { model: 'gemini-3.6-flash', outcome: 'overloaded', calls: 1, avg_ms: 20_000 },
    ]);
  });

  it('lists only the days of the month asked for', async () => {
    const detail = await admin.month('2026-09');
    expect(detail.days.map((day) => [day.day, day.usage['plan.gemini'].count, day.gemini[0].calls])).toEqual([['2026-09-01', 2, 2]]);
    expect((await admin.month('2026-07')).days).toEqual([]);
  });

  it("counts today's Gemini calls per model against the free daily limit", async () => {
    const overview = await admin.overview();
    expect(overview.today).toBe('2026-10-03');
    expect(overview.gemini_today).toEqual([
      { model: 'gemini-3.5-flash', calls: 1, ok: 1 },
      { model: 'gemini-3.6-flash', calls: 1, ok: 0 },
    ]);
    expect(overview.rate_limits).toEqual({ plan: '5 lần / 10 phút', adjust: 'tắt', admin: '5 lần / 15 phút' });
  });

  it('pages the Gemini log newest first and filters by outcome', async () => {
    const page = await admin.geminiCalls('2026-10', undefined, 1);
    expect(page.total).toBe(2);
    expect(page.calls.map((call) => call.outcome)).toEqual(['overloaded', 'ok']);
    expect((await admin.geminiCalls('2026-10', 'ok', 1)).calls).toHaveLength(1);
    expect((await admin.geminiCalls('2026-10', undefined, 2)).calls).toEqual([]);
  });
});
