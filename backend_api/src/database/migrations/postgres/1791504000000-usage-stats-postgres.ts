import type { MigrationInterface, QueryRunner } from 'typeorm';

// Thống kê sử dụng và nhật ký Gemini (giai đoạn 10) — Postgres, sinh từ schema diff của TypeORM trên DB rỗng.
export class UsageStatsPostgres1791504000000 implements MigrationInterface {
  name = 'UsageStatsPostgres1791504000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      'CREATE TABLE "gemini_calls" ("id" SERIAL NOT NULL, "day" character varying(10) NOT NULL, "created_at" TIMESTAMP NOT NULL, ' +
        '"task" character varying(16) NOT NULL, "model" character varying(64) NOT NULL, "attempt" integer NOT NULL, ' +
        '"outcome" character varying(16) NOT NULL, "http_status" integer, "duration_ms" integer NOT NULL, ' +
        '"message" character varying(300), CONSTRAINT "PK_cc683032f5654a79e8e5aeb2341" PRIMARY KEY ("id"))',
    );
    await queryRunner.query('CREATE INDEX "IDX_2e0036abc011feed924a5eaf8d" ON "gemini_calls" ("day")');
    await queryRunner.query(
      'CREATE TABLE "usage_daily" ("day" character varying(10) NOT NULL, "metric" character varying(64) NOT NULL, ' +
        '"count" integer NOT NULL, "total_ms" bigint NOT NULL, CONSTRAINT "PK_3e830b56be0c8b512f7514ed174" PRIMARY KEY ("day", "metric"))',
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP TABLE "usage_daily"');
    await queryRunner.query('DROP INDEX "public"."IDX_2e0036abc011feed924a5eaf8d"');
    await queryRunner.query('DROP TABLE "gemini_calls"');
  }
}
