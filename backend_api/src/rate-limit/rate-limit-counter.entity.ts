import { Column, Entity, PrimaryColumn } from 'typeorm';

// Bộ đếm giới hạn tần suất. Lưu trong DB chứ không trong RAM: trên Vercel mỗi instance có bộ nhớ riêng (P17 giai
// đoạn 9). RateLimitStore đọc/ghi bằng SQL thô (cộng dồn nguyên tử); entity này để migrations.spec.ts kiểm bảng
// khớp migration như mọi bảng khác.
@Entity('rate_limits')
export class RateLimitCounter {
  // SHA-256 của tên hạn mức + tài khoản hoặc IP — không lưu IP dạng chữ.
  @PrimaryColumn({ type: 'varchar', length: 64 })
  key: string;

  @Column({ type: 'integer' })
  hits: number;

  // Thời điểm hết cửa sổ đếm (mili-giây kể từ 1970).
  @Column({ type: 'bigint' })
  window_ends_at: string;
}
