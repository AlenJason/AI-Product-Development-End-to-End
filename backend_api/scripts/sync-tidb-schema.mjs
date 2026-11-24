import { DataSource } from 'typeorm';
import { User } from '../dist/database/entities/user.entity.js';
import { PlanRecord } from '../dist/database/entities/plan-record.entity.js';
import { FeedbackReceipt } from '../dist/database/entities/feedback-receipt.entity.js';
import { PlanMealItem } from '../dist/database/entities/plan-meal-item.entity.js';
import { PlanWorkoutItem } from '../dist/database/entities/plan-workout-item.entity.js';

const host = process.env.DB_HOST || 'localhost';
const port = Number(process.env.DB_PORT) || 4000;
const username = process.env.DB_USERNAME || 'root';
const password = process.env.DB_PASSWORD || '';
const database = process.env.DB_DATABASE || 'test';
const useSsl = process.env.DB_SSL === 'true';

console.log(`Connecting to TiDB Cloud (${host}:${port}/${database}) as ${username}...`);

const ds = new DataSource({
  type: 'mysql',
  host,
  port,
  username,
  password,
  database,
  entities: [User, PlanRecord, FeedbackReceipt, PlanMealItem, PlanWorkoutItem],
  synchronize: true,
  charset: 'utf8mb4',
  ssl: useSsl ? { minVersion: 'TLSv1.2', rejectUnauthorized: false } : undefined,
});

await ds.initialize();
console.log('Connected! TypeORM synchronized schema successfully.');

// Inspect tables
const tables = await ds.query('SHOW TABLES');
console.log('\nCurrent Tables in database:');
console.table(tables);

// Check columns of users
console.log('\nColumns of `users`:');
const userCols = await ds.query('SHOW COLUMNS FROM users');
console.table(userCols.map(c => ({ Field: c.Field, Type: c.Type, Null: c.Null })));

// Check columns of plan_records
console.log('\nColumns of `plan_records`:');
const planCols = await ds.query('SHOW COLUMNS FROM plan_records');
console.table(planCols.map(c => ({ Field: c.Field, Type: c.Type, Null: c.Null })));

// Check columns of plan_meal_items
console.log('\nColumns of `plan_meal_items`:');
const mealCols = await ds.query('SHOW COLUMNS FROM plan_meal_items');
console.table(mealCols.map(c => ({ Field: c.Field, Type: c.Type, Null: c.Null })));

// Check columns of plan_workout_items
console.log('\nColumns of `plan_workout_items`:');
const workoutCols = await ds.query('SHOW COLUMNS FROM plan_workout_items');
console.table(workoutCols.map(c => ({ Field: c.Field, Type: c.Type, Null: c.Null })));

// Check columns of feedback_receipts
console.log('\nColumns of `feedback_receipts`:');
const fbCols = await ds.query('SHOW COLUMNS FROM feedback_receipts');
console.table(fbCols.map(c => ({ Field: c.Field, Type: c.Type, Null: c.Null })));

// Backfill existing records if any
console.log('\nChecking for any existing records to backfill...');

// 1. Backfill users
const existingUsers = await ds.query('SELECT id, profile_json FROM users WHERE profile_json IS NOT NULL AND bmi IS NULL');
console.log(`Found ${existingUsers.length} user(s) to backfill.`);
for (const u of existingUsers) {
  try {
    const prof = typeof u.profile_json === 'string' ? JSON.parse(u.profile_json) : u.profile_json;
    if (prof) {
      const age = typeof prof.age === 'number' ? prof.age : null;
      const gender = typeof prof.gender === 'string' ? prof.gender : null;
      const height = typeof prof.height_cm === 'number' ? prof.height_cm : null;
      const weight = typeof prof.weight_kg === 'number' ? prof.weight_kg : null;
      const goal = typeof prof.goal === 'string' ? prof.goal : null;
      const activity = typeof prof.activity_level === 'string' ? prof.activity_level : null;
      const bmi = (weight && height) ? Math.round((weight / ((height / 100) ** 2)) * 10) / 10 : null;

      await ds.query(
        'UPDATE users SET age = ?, gender = ?, height_cm = ?, weight_kg = ?, bmi = ?, goal = ?, activity_level = ? WHERE id = ?',
        [age, gender, height, weight, bmi, goal, activity, u.id]
      );
      console.log(`Backfilled user ${u.id}`);
    }
  } catch (e) {
    console.error(`Failed to backfill user ${u.id}:`, e);
  }
}

// 2. Backfill plan_records
const existingPlans = await ds.query('SELECT id, plan_json FROM plan_records WHERE plan_json IS NOT NULL');
console.log(`Found ${existingPlans.length} plan(s) to check/backfill.`);
for (const p of existingPlans) {
  try {
    const plan = typeof p.plan_json === 'string' ? JSON.parse(p.plan_json) : p.plan_json;
    if (plan) {
      const daily = plan.daily_target;
      await ds.query(
        'UPDATE plan_records SET source = ?, bmi = ?, bmr = ?, tdee = ?, protein_g = ?, carbs_g = ?, fat_g = ?, day_count = ? WHERE id = ?',
        [
          plan.source || null,
          daily?.bmi || null,
          daily?.bmr || null,
          daily?.tdee || null,
          daily?.protein_g || null,
          daily?.carbs_g || null,
          daily?.fat_g || null,
          plan.days?.length || 3,
          p.id
        ]
      );

      // Populate plan_meal_items & plan_workout_items
      await ds.query('DELETE FROM plan_meal_items WHERE plan_id = ?', [p.id]);
      await ds.query('DELETE FROM plan_workout_items WHERE plan_id = ?', [p.id]);

      const now = new Date();
      for (const day of plan.days || []) {
        for (const meal of day.meals || []) {
          const ingStr = meal.ingredients?.map(i => `${i.name} (${i.amount}${i.unit})`).join(', ') || null;
          await ds.query(
            'INSERT INTO plan_meal_items (id, plan_id, day_number, meal_type, meal_name, portion, calories, protein_g, carbs_g, fat_g, ingredient_summary, created_at) VALUES (UUID(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [p.id, day.day_number, meal.meal_type, meal.name, meal.portion || null, meal.calories, meal.protein_g ?? null, meal.carbs_g ?? null, meal.fat_g ?? null, ingStr, now]
          );
        }

        if (day.workout) {
          for (const ex of day.workout.exercises || []) {
            await ds.query(
              'INSERT INTO plan_workout_items (id, plan_id, day_number, workout_title, exercise_name, sets, reps_or_duration, muscle_group, created_at) VALUES (UUID(), ?, ?, ?, ?, ?, ?, ?, ?)',
              [p.id, day.day_number, day.workout.title || null, ex.name, ex.sets ?? null, ex.reps_or_duration || null, ex.muscle_group || null, now]
            );
          }
        }
      }
      console.log(`Backfilled plan breakdown for ${p.id}`);
    }
  } catch (e) {
    console.error(`Failed to backfill plan ${p.id}:`, e);
  }
}

await ds.destroy();
console.log('\nAll done! Database is fully up to date and human-readable.');
