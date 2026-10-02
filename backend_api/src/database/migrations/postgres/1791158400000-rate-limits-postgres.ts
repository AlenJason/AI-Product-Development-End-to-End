import type { MigrationInterface, QueryRunner } from 'typeorm';

// Bảng bộ đếm giới hạn tần suất (PLAN 9.7) — Postgres. Cùng schema với migrations/1791158400000-rate-limits.ts.
export class RateLimitsPostgres1791158400000 implements MigrationInterface {
  name = 'RateLimitsPostgres1791158400000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      'CREATE TABLE "rate_limits" ("key" character varying(64) NOT NULL, "hits" integer NOT NULL, ' +
        '"window_ends_at" bigint NOT NULL, CONSTRAINT "PK_8cb6aa4831e3e775ccf370521db" PRIMARY KEY ("key"))',
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP TABLE "rate_limits"');
  }
}
