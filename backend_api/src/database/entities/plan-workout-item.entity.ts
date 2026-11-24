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

@Entity('plan_workout_items')
export class PlanWorkoutItem {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 36 })
  @Index()
  plan_id: string;

  @ManyToOne(() => PlanRecord, (plan) => plan.workouts, { onDelete: 'CASCADE', nullable: false })
  @JoinColumn({ name: 'plan_id' })
  plan: Relation<PlanRecord>;

  @Column({ type: 'integer' })
  day_number: number;

  @Column({ type: 'varchar', length: 255, nullable: true })
  workout_title: string | null;

  @Column({ type: 'varchar', length: 255 })
  exercise_name: string;

  @Column({ type: 'integer', nullable: true })
  sets: number | null;

  @Column({ type: 'varchar', length: 100, nullable: true })
  reps_or_duration: string | null;

  @Column({ type: 'varchar', length: 100, nullable: true })
  muscle_group: string | null;

  @Column({ type: 'datetime' })
  created_at: Date;
}
