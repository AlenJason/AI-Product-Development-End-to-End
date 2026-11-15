import { TableColumn, type MigrationInterface, type QueryRunner } from 'typeorm';

export class UserProfile1794500000000 implements MigrationInterface {
  name = 'UserProfile1794500000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.addColumn(
      'users',
      new TableColumn({
        name: 'profile_json',
        type: 'text',
        isNullable: true,
      }),
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.dropColumn('users', 'profile_json');
  }
}
