import { Table, type MigrationInterface, type QueryRunner } from 'typeorm';
export class FeedbackReceipts1793498400000 implements MigrationInterface {
  name = 'FeedbackReceipts1793498400000';
  async up(r: QueryRunner): Promise<void> {
    await r.createTable(
      new Table({
        name: 'feedback_receipts',
        columns: [
          { name: 'plan_id', type: 'varchar', isPrimary: true },
          { name: 'day_number', type: 'integer', isPrimary: true },
          { name: 'owner_id', type: 'varchar', isNullable: true },
          { name: 'request_hash', type: 'varchar' },
          { name: 'status', type: 'varchar' },
          { name: 'token', type: 'varchar' },
          { name: 'lease_until', type: 'bigint' },
          { name: 'result_json', type: 'text', isNullable: true },
        ],
      }),
    );
  }
  async down(r: QueryRunner): Promise<void> {
    await r.dropTable('feedback_receipts');
  }
}
