import type { MigrationInterface, QueryRunner } from 'typeorm';

// Cùng schema với InitialSchema1790208000000 (SQLite), viết cho Postgres (production — Neon). SQL lấy đúng từ schema
// diff của TypeORM trên DB rỗng; migrations.spec.ts kiểm lại trên Postgres thật (TEST_DATABASE_URL).
export class InitialSchemaPostgres1791072000000 implements MigrationInterface {
  name = 'InitialSchemaPostgres1791072000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      'CREATE TABLE "users" ("id" uuid NOT NULL DEFAULT gen_random_uuid(), "google_sub" character varying(255) NOT NULL, ' +
        '"email" character varying(320) NOT NULL, "name" character varying(200) NOT NULL, ' +
        '"created_at" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "UQ_68b61ba0fb359b93b517cf1073d" UNIQUE ("google_sub"), ' +
        'CONSTRAINT "PK_a3ffb1c0c8416b9fc6f907b7433" PRIMARY KEY ("id"))',
    );
    await queryRunner.query(
      'CREATE TABLE "plan_records" ("id" character varying(36) NOT NULL, "user_id" uuid NOT NULL, ' +
        '"target_calories" integer NOT NULL, "plan_json" text NOT NULL, "created_at" TIMESTAMP NOT NULL, ' +
        'CONSTRAINT "PK_55fc1dcf23da98621a180059449" PRIMARY KEY ("id"))',
    );
    await queryRunner.query('CREATE INDEX "IDX_c55ecbac63bad2e89228039494" ON "plan_records" ("user_id", "created_at")');
    await queryRunner.query(
      'ALTER TABLE "plan_records" ADD CONSTRAINT "FK_e4de63ebd727c8027fb80938dfb" FOREIGN KEY ("user_id") ' +
        'REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION',
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('ALTER TABLE "plan_records" DROP CONSTRAINT "FK_e4de63ebd727c8027fb80938dfb"');
    await queryRunner.query('DROP INDEX "public"."IDX_c55ecbac63bad2e89228039494"');
    await queryRunner.query('DROP TABLE "plan_records"');
    await queryRunner.query('DROP TABLE "users"');
  }
}
