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
  @Column({ type: 'integer' }) lease_until: number;
  @Column({ type: 'simple-json', nullable: true })
  result_json: FeedbackResult | null;
}
