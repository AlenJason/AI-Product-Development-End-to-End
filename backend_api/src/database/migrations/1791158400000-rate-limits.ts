import type { MigrationInterface, QueryRunner } from 'typeorm';

// Bảng bộ đếm giới hạn tần suất (PLAN 9.7) — SQLite. Bản Postgres: migrations/postgres/1791158400000-rate-limits-postgres.ts.
export class RateLimits1791158400000 implements MigrationInterface {
  name = 'RateLimits1791158400000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      'CREATE TABLE "rate_limits" ("key" varchar(64) PRIMARY KEY NOT NULL, "hits" integer NOT NULL, ' +
        '"window_ends_at" bigint NOT NULL)',
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP TABLE "rate_limits"');
  }
}
