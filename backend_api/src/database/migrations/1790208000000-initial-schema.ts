import { type MigrationInterface, type QueryRunner, Table } from 'typeorm';

// Khớp từng cột với entity — migrations.spec.ts kiểm bằng schema diff của TypeORM.
export class InitialSchema1790208000000 implements MigrationInterface {
  name = 'InitialSchema1790208000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.createTable(
      new Table({
        name: 'users',
        columns: [
          { name: 'id', type: 'varchar', isPrimary: true },
          { name: 'google_sub', type: 'varchar', length: '255', isUnique: true },
          { name: 'email', type: 'varchar', length: '320' },
          { name: 'name', type: 'varchar', length: '200' },
          { name: 'created_at', type: 'datetime', default: "datetime('now')" },
        ],
      }),
    );
    await queryRunner.createTable(
      new Table({
        name: 'plan_records',
        columns: [
          { name: 'id', type: 'varchar', length: '36', isPrimary: true },
          { name: 'target_calories', type: 'integer' },
          { name: 'plan_json', type: 'text' },
          { name: 'created_at', type: 'datetime' },
          { name: 'user_id', type: 'varchar' },
        ],
        foreignKeys: [
          {
            columnNames: ['user_id'],
            referencedTableName: 'users',
            referencedColumnNames: ['id'],
            onDelete: 'CASCADE',
          },
        ],
        indices: [{ columnNames: ['user_id', 'created_at'] }],
      }),
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.dropTable('plan_records');
    await queryRunner.dropTable('users');
  }
}
