import { randomUUID } from 'node:crypto';
import { DataSource } from 'typeorm';
import { createMemoryDataSource } from '../../../test/memory-data-source.js';
import { TEST_DATABASE_URL, resetPostgres } from '../../../test/postgres-test-db.js';
import { WARNINGS } from '../../plan/plan-warnings.js';
import { dataSourceOptions } from '../data-source-options.js';
import { PlanRecord } from '../entities/plan-record.entity.js';
import { User } from '../entities/user.entity.js';

// Migration 1791590400000 (BRD 2.10.1): kế hoạch đã lưu trước đó còn câu cảnh báo mang thai / có bệnh nền.
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

describe.each(targets)('migration bỏ cảnh báo sức khoẻ khỏi lịch sử (%s)', (_name, open) => {
  let dataSource: DataSource;
  const rawJson = async () =>
    Object.fromEntries(
      ((await dataSource.query('SELECT id, plan_json FROM plan_records')) as { id: string; plan_json: string }[]).map((row) => [row.id, row.plan_json]),
    );

  beforeEach(async () => {
    dataSource = await open();
  });

  afterEach(async () => {
    if (dataSource.isInitialized) await dataSource.destroy();
  });

  it('removes only the pregnancy and health-condition warnings from plans saved earlier', async () => {
    const user = await dataSource.getRepository(User).save({ google_sub: 'mock:cu@vku.edu.vn', email: 'cu@vku.edu.vn', name: 'cu' });
    const plan = (warnings: string[]) => ({ plan_id: randomUUID(), warnings, daily_target: { target_calories: 1800 }, days: [{ day_number: 1 }] });
    const old = plan([WARNINGS.bmrFloor(1399), WARNINGS.healthConditions, WARNINGS.pregnancy, WARNINGS.sampleKeywordFiltered]);
    const clean = plan([WARNINGS.sampleKeywordFiltered]);
    await dataSource.getRepository(PlanRecord).insert(
      [old, clean].map((p) => ({ id: p.plan_id, user_id: user.id, target_calories: 1800, plan_json: p as never, created_at: new Date() })),
    );
    const before = await rawJson();

    // Chạy lại đúng migration đã đăng ký (bản SQLite hoặc Postgres), như lúc deploy lên DB đã có dữ liệu.
    await dataSource.undoLastMigration();
    expect(await dataSource.runMigrations()).toHaveLength(1);

    const after = await rawJson();
    expect(JSON.parse(after[old.plan_id])).toEqual({ ...old, warnings: [WARNINGS.bmrFloor(1399), WARNINGS.sampleKeywordFiltered] });
    expect(after[clean.plan_id]).toBe(before[clean.plan_id]); // dòng không có câu nào cần bỏ thì giữ nguyên
  });
});
