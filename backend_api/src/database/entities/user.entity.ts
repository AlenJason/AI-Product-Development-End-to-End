import { Column, CreateDateColumn, Entity, OneToMany, PrimaryGeneratedColumn, type Relation } from 'typeorm';
import { PlanRecord } from './plan-record.entity.js';

// Lưu thông tin định danh tài khoản và mật khẩu đã băm — không lưu dữ liệu sức khoẻ (NFR-5, NFR-7).
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

  @CreateDateColumn()
  created_at: Date;

  // Quan hệ giữa hai entity import lẫn nhau phải bọc Relation<>: nếu không, bản build ESM ghi
  // metadata kiểu (emitDecoratorMetadata) trỏ tới class chưa khởi tạo → ReferenceError lúc khởi động.
  // Vitest không bắt được lỗi này; `npm run test:smoke` chạy bản build thì bắt được.
  @OneToMany(() => PlanRecord, (plan) => plan.user)
  plans: Relation<PlanRecord[]>;
}
