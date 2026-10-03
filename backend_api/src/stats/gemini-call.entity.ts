import { Column, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

// Nhật ký Gemini (giai đoạn 10, quyết định Q5): mỗi lần gọi Gemini một dòng — tính năng, model, kết quả, mã lỗi,
// thời gian. Không có người gọi, prompt, kết quả trả về hay chi tiết vi phạm hợp đồng (có thể trích nội dung, #12).
// Giữ mãi: ≤ ~40 lần gọi/ngày (20 lượt × 2 model) ≈ 15.000 dòng/năm.
@Entity('gemini_calls')
@Index(['day'])
export class GeminiCall {
  @PrimaryGeneratedColumn()
  id: number;

  // YYYY-MM-DD theo giờ Việt Nam — lọc theo tháng bằng cùng một câu SQL trên cả hai loại DB (#38).
  @Column({ type: 'varchar', length: 10 })
  day: string;

  @Column()
  created_at: Date;

  // plan | meal_swap | exercise_swap | feedback
  @Column({ type: 'varchar', length: 16 })
  task: string;

  @Column({ type: 'varchar', length: 64 })
  model: string;

  // Lần gọi thứ mấy trong một request (1–4).
  @Column({ type: 'integer' })
  attempt: number;

  // ok | timeout | overloaded | quota | invalid | error
  @Column({ type: 'varchar', length: 16 })
  outcome: string;

  @Column({ type: 'integer', nullable: true })
  http_status: number | null;

  @Column({ type: 'integer' })
  duration_ms: number;

  // Thông báo ngắn của Google (describeGeminiError) hoặc câu chung — không bao giờ có nội dung Gemini trả về.
  @Column({ type: 'varchar', length: 300, nullable: true })
  message: string | null;
}
