import {
  Table,
  TableColumn,
  type MigrationInterface,
  type QueryRunner,
} from 'typeorm';

export class ReadableSchema1795540000000 implements MigrationInterface {
  name = 'ReadableSchema1795540000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    // 1. Cột thể chất rõ ràng trên users
    await queryRunner.addColumns('users', [
      new TableColumn({ name: 'age', type: 'integer', isNullable: true }),
      new TableColumn({ name: 'gender', type: 'varchar', length: '20', isNullable: true }),
      new TableColumn({ name: 'height_cm', type: 'float', isNullable: true }),
      new TableColumn({ name: 'weight_kg', type: 'float', isNullable: true }),
      new TableColumn({ name: 'bmi', type: 'float', isNullable: true }),
      new TableColumn({ name: 'goal', type: 'varchar', length: '50', isNullable: true }),
      new TableColumn({ name: 'activity_level', type: 'varchar', length: '50', isNullable: true }),
    ]);

    // 2. Cột mục tiêu calo, macro rõ ràng trên plan_records
    await queryRunner.addColumns('plan_records', [
      new TableColumn({ name: 'source', type: 'varchar', length: '50', isNullable: true }),
      new TableColumn({ name: 'bmi', type: 'float', isNullable: true }),
      new TableColumn({ name: 'bmr', type: 'integer', isNullable: true }),
      new TableColumn({ name: 'tdee', type: 'integer', isNullable: true }),
      new TableColumn({ name: 'protein_g', type: 'integer', isNullable: true }),
      new TableColumn({ name: 'carbs_g', type: 'integer', isNullable: true }),
      new TableColumn({ name: 'fat_g', type: 'integer', isNullable: true }),
      new TableColumn({ name: 'day_count', type: 'integer', isNullable: true }),
    ]);

    // 3. Cột trạng thái phản hồi rõ ràng trên feedback_receipts
    await queryRunner.addColumns('feedback_receipts', [
      new TableColumn({ name: 'eating_status', type: 'varchar', length: '50', isNullable: true }),
      new TableColumn({ name: 'energy_level', type: 'varchar', length: '50', isNullable: true }),
      new TableColumn({ name: 'feedback_summary', type: 'text', isNullable: true }),
      new TableColumn({ name: 'has_danger_signs', type: 'boolean', isNullable: true }),
      new TableColumn({ name: 'safety_warning', type: 'text', isNullable: true }),
    ]);

    // 4. Bảng chi tiết từng món ăn trong kế hoạch
    await queryRunner.createTable(
      new Table({
        name: 'plan_meal_items',
        columns: [
          { name: 'id', type: 'varchar', isPrimary: true },
          { name: 'plan_id', type: 'varchar', length: '36' },
          { name: 'day_number', type: 'integer' },
          { name: 'meal_type', type: 'varchar', length: '50' },
          { name: 'meal_name', type: 'varchar', length: '255' },
          { name: 'portion', type: 'varchar', length: '100', isNullable: true },
          { name: 'calories', type: 'integer' },
          { name: 'protein_g', type: 'float', isNullable: true },
          { name: 'carbs_g', type: 'float', isNullable: true },
          { name: 'fat_g', type: 'float', isNullable: true },
          { name: 'ingredient_summary', type: 'text', isNullable: true },
          { name: 'created_at', type: 'datetime' },
        ],
        foreignKeys: [
          {
            columnNames: ['plan_id'],
            referencedTableName: 'plan_records',
            referencedColumnNames: ['id'],
            onDelete: 'CASCADE',
          },
        ],
        indices: [{ columnNames: ['plan_id'] }],
      }),
    );

    // 5. Bảng chi tiết từng bài tập thể dục trong kế hoạch
    await queryRunner.createTable(
      new Table({
        name: 'plan_workout_items',
        columns: [
          { name: 'id', type: 'varchar', isPrimary: true },
          { name: 'plan_id', type: 'varchar', length: '36' },
          { name: 'day_number', type: 'integer' },
          { name: 'workout_title', type: 'varchar', length: '255', isNullable: true },
          { name: 'exercise_name', type: 'varchar', length: '255' },
          { name: 'sets', type: 'integer', isNullable: true },
          { name: 'reps_or_duration', type: 'varchar', length: '100', isNullable: true },
          { name: 'muscle_group', type: 'varchar', length: '100', isNullable: true },
          { name: 'created_at', type: 'datetime' },
        ],
        foreignKeys: [
          {
            columnNames: ['plan_id'],
            referencedTableName: 'plan_records',
            referencedColumnNames: ['id'],
            onDelete: 'CASCADE',
          },
        ],
        indices: [{ columnNames: ['plan_id'] }],
      }),
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.dropTable('plan_workout_items');
    await queryRunner.dropTable('plan_meal_items');

    await queryRunner.dropColumns('feedback_receipts', [
      'eating_status',
      'energy_level',
      'feedback_summary',
      'has_danger_signs',
      'safety_warning',
    ]);

    await queryRunner.dropColumns('plan_records', [
      'source',
      'bmi',
      'bmr',
      'tdee',
      'protein_g',
      'carbs_g',
      'fat_g',
      'day_count',
    ]);

    await queryRunner.dropColumns('users', [
      'age',
      'gender',
      'height_cm',
      'weight_kg',
      'bmi',
      'goal',
      'activity_level',
    ]);
  }
}
