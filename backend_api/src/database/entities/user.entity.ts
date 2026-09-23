import { Column, CreateDateColumn, Entity, OneToMany, PrimaryGeneratedColumn, type Relation } from 'typeorm';
import { PlanRecord } from './plan-record.entity.js';

// Chỉ lưu thông tin định danh từ Google — không mật khẩu, không dữ liệu sức khoẻ (NFR-5, NFR-7).
@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  // `sub` của Google ID Token; chế độ AUTH_MODE=mock dùng `mock:<email>`.
  @Column({ type: 'varchar', length: 255, unique: true })
  google_sub: string;

  @Column({ type: 'varchar', length: 320 })
  email: string;

  @Column({ type: 'varchar', length: 200 })
  name: string;

  @CreateDateColumn()
  created_at: Date;

  // Quan hệ giữa hai entity import lẫn nhau phải bọc Relation<>: nếu không, bản build ESM ghi
  // metadata kiểu (emitDecoratorMetadata) trỏ tới class chưa khởi tạo → ReferenceError lúc khởi động.
  // Vitest không bắt được lỗi này; `npm run test:smoke` chạy bản build thì bắt được.
  @OneToMany(() => PlanRecord, (plan) => plan.user)
  plans: Relation<PlanRecord[]>;
}
