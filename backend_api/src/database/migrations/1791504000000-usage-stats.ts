import type { MigrationInterface, QueryRunner } from 'typeorm';

// Thống kê sử dụng và nhật ký Gemini (giai đoạn 10) — SQLite. Bản Postgres: migrations/postgres/1791504000000-usage-stats-postgres.ts.
export class UsageStats1791504000000 implements MigrationInterface {
  name = 'UsageStats1791504000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      'CREATE TABLE "gemini_calls" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "day" varchar(10) NOT NULL, ' +
        '"created_at" datetime NOT NULL, "task" varchar(16) NOT NULL, "model" varchar(64) NOT NULL, "attempt" integer NOT NULL, ' +
        '"outcome" varchar(16) NOT NULL, "http_status" integer, "duration_ms" integer NOT NULL, "message" varchar(300))',
    );
    await queryRunner.query('CREATE INDEX "IDX_2e0036abc011feed924a5eaf8d" ON "gemini_calls" ("day")');
    await queryRunner.query(
      'CREATE TABLE "usage_daily" ("day" varchar(10) NOT NULL, "metric" varchar(64) NOT NULL, "count" integer NOT NULL, ' +
        '"total_ms" bigint NOT NULL, PRIMARY KEY ("day", "metric"))',
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP TABLE "usage_daily"');
    await queryRunner.query('DROP INDEX "IDX_2e0036abc011feed924a5eaf8d"');
    await queryRunner.query('DROP TABLE "gemini_calls"');
  }
}
