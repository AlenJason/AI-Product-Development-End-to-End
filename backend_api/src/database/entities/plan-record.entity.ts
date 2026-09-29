import { Column, Entity, Index, JoinColumn, ManyToOne, PrimaryColumn, type Relation } from 'typeorm';
import type { MealPlanResponseDto } from '../../plan/dto/meal-plan-response.dto.js';
import { User } from './user.entity.js';

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

  // Đúng response đã trả cho app; response không có `restrictions` (NFR-7, #12).
  @Column({ type: 'simple-json' })
  plan_json: MealPlanResponseDto;

  // Code tự gán (mili-giây); mặc định của SQLite chỉ chính xác tới giây, hai plan liền nhau sẽ trùng giờ.
  @Column({ type: 'datetime' })
  created_at: Date;
}
