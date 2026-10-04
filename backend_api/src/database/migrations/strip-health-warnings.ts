import type { QueryRunner } from 'typeorm';
import { withoutHealthStatusWarnings } from '../../plan/plan-warnings.js';
import { sqlParams } from '../sql-params.js';

// Kế hoạch lưu trước bản 2.10.1 còn nguyên câu cảnh báo mang thai / có bệnh nền trong `warnings` — bỏ khỏi từng dòng
// (NFR-7). Chỉ đổi dữ liệu, không đổi schema; dùng chung cho migration SQLite và Postgres.
export async function stripHealthWarningsFromHistory(queryRunner: QueryRunner): Promise<void> {
  const rows: { id: string; plan_json: string }[] = await queryRunner.query('SELECT id, plan_json FROM plan_records');
  for (const row of rows) {
    const plan = JSON.parse(row.plan_json) as { warnings?: unknown };
    if (!Array.isArray(plan.warnings)) continue;
    const cleaned = withoutHealthStatusWarnings(plan as { warnings: string[] });
    if (cleaned.warnings.length === plan.warnings.length) continue;
    const { p, params } = sqlParams(queryRunner.connection, [JSON.stringify(cleaned), row.id]);
    await queryRunner.query(`UPDATE plan_records SET plan_json = ${p(1)} WHERE id = ${p(2)}`, params);
  }
}
