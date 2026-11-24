import { Column, CreateDateColumn, Entity, OneToMany, PrimaryGeneratedColumn, type Relation } from 'typeorm';
import { PlanRecord } from './plan-record.entity.js';

// Lưu thông tin định danh tài khoản, mật khẩu đã băm và các chỉ số thể chất cơ bản — không lưu bệnh lý/dị ứng nhạy cảm (NFR-5, NFR-7, D4, D5).
@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 320, unique: true })
  email: string;

  @Column({ type: 'varchar', length: 200 })
  name: string;

  @Column({ type: 'varchar', length: 255, nullable: true })
  password_hash: string | null;

  @Column({ type: 'text', nullable: true })
  profile_json: string | null;

  // Các trường thể chất hiển thị rõ ràng khi xem bảng (không cần bóc tách JSON)
  @Column({ type: 'integer', nullable: true })
  age: number | null;

  @Column({ type: 'varchar', length: 20, nullable: true })
  gender: string | null;

  @Column({ type: 'float', nullable: true })
  height_cm: number | null;

  @Column({ type: 'float', nullable: true })
  weight_kg: number | null;

  @Column({ type: 'float', nullable: true })
  bmi: number | null;

  @Column({ type: 'varchar', length: 50, nullable: true })
  goal: string | null;

  @Column({ type: 'varchar', length: 50, nullable: true })
  activity_level: string | null;

  @CreateDateColumn()
  created_at: Date;

  // Quan hệ giữa hai entity import lẫn nhau phải bọc Relation<>: nếu không, bản build ESM ghi
  // metadata kiểu (emitDecoratorMetadata) trỏ tới class chưa khởi tạo → ReferenceError lúc khởi động.
  // Vitest không bắt được lỗi này; `npm run test:smoke` chạy bản build thì bắt được.
  @OneToMany(() => PlanRecord, (plan) => plan.user)
  plans: Relation<PlanRecord[]>;
}
