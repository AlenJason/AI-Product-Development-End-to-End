import type { MigrationInterface, QueryRunner } from 'typeorm';
import { stripHealthWarningsFromHistory } from './strip-health-warnings.js';

// Bỏ câu cảnh báo sức khoẻ khỏi kế hoạch đã lưu (BRD 2.10.1, NFR-7) — SQLite.
// Bản Postgres: migrations/postgres/1791590400000-strip-health-warnings-postgres.ts.
export class StripHealthWarnings1791590400000 implements MigrationInterface {
  name = 'StripHealthWarnings1791590400000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await stripHealthWarningsFromHistory(queryRunner);
  }

  // Không khôi phục: các câu này không được phép nằm trong lịch sử.
  async down(): Promise<void> {
    // Không có gì để hoàn tác.
  }
}
