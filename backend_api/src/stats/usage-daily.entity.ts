import { Column, Entity, PrimaryColumn } from 'typeorm';

// Thống kê sử dụng (giai đoạn 10, quyết định Q5): mỗi ngày (giờ Việt Nam) × loại số liệu một dòng — chỉ có số đếm,
// không dòng nào gắn với một người. StatsService cộng dồn bằng SQL thô (nguyên tử); entity này để migrations.spec.ts
// kiểm bảng khớp migration. Giữ mãi: ~40 loại × 365 ngày ≈ 15.000 dòng/năm.
@Entity('usage_daily')
export class UsageDaily {
  // YYYY-MM-DD theo giờ Việt Nam (UTC+7) — trang Admin cộng thành tháng bằng 7 ký tự đầu.
  @PrimaryColumn({ type: 'varchar', length: 10 })
  day: string;

  @PrimaryColumn({ type: 'varchar', length: 64 })
  metric: string;

  @Column({ type: 'integer' })
  count: number;

  // Tổng thời gian (ms) của các lần được đếm — chia cho count ra thời gian trung bình.
  @Column({ type: 'bigint' })
  total_ms: string;
}
