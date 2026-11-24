import { Column, Entity, Index, JoinColumn, ManyToOne, OneToMany, PrimaryColumn, type Relation } from 'typeorm';
import type { MealPlanResponseDto } from '../../plan/dto/meal-plan-response.dto.js';
import { User } from './user.entity.js';
import { PlanMealItem } from './plan-meal-item.entity.js';
import { PlanWorkoutItem } from './plan-workout-item.entity.js';

@Entity('plan_records')
@Index(['user', 'created_at'])
export class PlanRecord {
  // Chính là `plan_id` do server gán trong assemblePlan() (#16).
  @PrimaryColumn({ type: 'varchar', length: 36 })
  id: string;

  @ManyToOne(() => User, (user) => user.plans, { onDelete: 'CASCADE', nullable: false })
  @JoinColumn({ name: 'user_id' })
  user: Relation<User>; // Relation<>: hai entity import lẫn nhau, xem user.entity.ts

  @Column({ type: 'varchar' })
  user_id: string;

  // Tách riêng để trả danh sách lịch sử mà không phải đọc cả JSON.
  @Column({ type: 'integer' })
  target_calories: number;

  // Các trường số liệu dinh dưỡng tường minh, dễ đọc trực tiếp từ bảng
  @Column({ type: 'varchar', length: 50, nullable: true })
  source: string | null;

  @Column({ type: 'float', nullable: true })
  bmi: number | null;

  @Column({ type: 'integer', nullable: true })
  bmr: number | null;

  @Column({ type: 'integer', nullable: true })
  tdee: number | null;

  @Column({ type: 'integer', nullable: true })
  protein_g: number | null;

  @Column({ type: 'integer', nullable: true })
  carbs_g: number | null;

  @Column({ type: 'integer', nullable: true })
  fat_g: number | null;

  @Column({ type: 'integer', nullable: true })
  day_count: number | null;

  // Đúng response đã trả cho app; response không có `restrictions` (NFR-7, #12).
  @Column({ type: 'simple-json' })
  plan_json: MealPlanResponseDto;

  // Code tự gán (mili-giây); mặc định của SQLite chỉ chính xác tới giây, hai plan liền nhau sẽ trùng giờ.
  @Column({ type: 'datetime' })
  created_at: Date;

  @OneToMany(() => PlanMealItem, (meal) => meal.plan)
  meals: Relation<PlanMealItem[]>;

  @OneToMany(() => PlanWorkoutItem, (workout) => workout.plan)
  workouts: Relation<PlanWorkoutItem[]>;
}
