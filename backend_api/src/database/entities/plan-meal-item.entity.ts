import {
  Column,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  type Relation,
} from 'typeorm';
import { PlanRecord } from './plan-record.entity.js';

@Entity('plan_meal_items')
export class PlanMealItem {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 36 })
  @Index()
  plan_id: string;

  @ManyToOne(() => PlanRecord, (plan) => plan.meals, { onDelete: 'CASCADE', nullable: false })
  @JoinColumn({ name: 'plan_id' })
  plan: Relation<PlanRecord>;

  @Column({ type: 'integer' })
  day_number: number;

  @Column({ type: 'varchar', length: 50 })
  meal_type: string;

  @Column({ type: 'varchar', length: 255 })
  meal_name: string;

  @Column({ type: 'varchar', length: 100, nullable: true })
  portion: string | null;

  @Column({ type: 'integer' })
  calories: number;

  @Column({ type: 'float', nullable: true })
  protein_g: number | null;

  @Column({ type: 'float', nullable: true })
  carbs_g: number | null;

  @Column({ type: 'float', nullable: true })
  fat_g: number | null;

  @Column({ type: 'text', nullable: true })
  ingredient_summary: string | null;

  @Column({ type: 'datetime' })
  created_at: Date;
}
