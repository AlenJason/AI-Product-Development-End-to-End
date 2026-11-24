import { Column, Entity, PrimaryColumn } from 'typeorm';
import type { FeedbackResult } from '../../plan/adjust/feedback.service.js';

@Entity('feedback_receipts')
export class FeedbackReceipt {
  @PrimaryColumn({ type: 'varchar' }) plan_id: string;
  @PrimaryColumn({ type: 'integer' }) day_number: number;
  @Column({ type: 'varchar', nullable: true }) owner_id: string | null;
  @Column({ type: 'varchar' }) request_hash: string;
  @Column({ type: 'varchar' }) status: 'processing' | 'completed';
  @Column({ type: 'varchar' }) token: string;
  @Column({ type: 'bigint' }) lease_until: number;

  // Các trường tường minh giúp xem trực tiếp trên giao diện DB
  @Column({ type: 'varchar', length: 50, nullable: true })
  eating_status: string | null;

  @Column({ type: 'varchar', length: 50, nullable: true })
  energy_level: string | null;

  @Column({ type: 'text', nullable: true })
  feedback_summary: string | null;

  @Column({ type: 'boolean', nullable: true })
  has_danger_signs: boolean | null;

  @Column({ type: 'text', nullable: true })
  safety_warning: string | null;

  @Column({ type: 'simple-json', nullable: true })
  result_json: FeedbackResult | null;
}
