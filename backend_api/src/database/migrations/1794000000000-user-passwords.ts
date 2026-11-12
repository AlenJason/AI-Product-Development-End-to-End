import { TableColumn, type MigrationInterface, type QueryRunner } from 'typeorm';

export class UserPasswords1794000000000 implements MigrationInterface {
  name = 'UserPasswords1794000000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.addColumn(
      'users',
      new TableColumn({
        name: 'password_hash',
        type: 'varchar',
        length: '255',
        isNullable: true,
      }),
    );
    await queryRunner.dropColumn('users', 'google_sub');
    await queryRunner.changeColumn(
      'users',
      'email',
      new TableColumn({
        name: 'email',
        type: 'varchar',
        length: '320',
        isUnique: true,
      }),
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.changeColumn(
      'users',
      'email',
      new TableColumn({
        name: 'email',
        type: 'varchar',
        length: '320',
      }),
    );
    await queryRunner.addColumn(
      'users',
      new TableColumn({
        name: 'google_sub',
        type: 'varchar',
        length: '255',
        isUnique: true,
      }),
    );
    await queryRunner.dropColumn('users', 'password_hash');
  }
}

