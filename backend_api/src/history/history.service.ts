import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import type { Repository } from 'typeorm';
import { PlanRecord } from '../database/entities/plan-record.entity.js';
import { PlanMealItem } from '../database/entities/plan-meal-item.entity.js';
import { PlanWorkoutItem } from '../database/entities/plan-workout-item.entity.js';
import type { MealPlanResponseDto } from '../plan/dto/meal-plan-response.dto.js';
import type { PlanHistoryResponseDto } from './dto/plan-history-response.dto.js';

export const HISTORY_LIMIT = 50;

@Injectable()
export class HistoryService {
  private readonly logger = new Logger(HistoryService.name);

  constructor(
    @InjectRepository(PlanRecord)
    private readonly plans: Repository<PlanRecord>,
  ) {}

  // Trả false thay vì ném lỗi: lịch sử lỗi không được làm mất plan vừa tạo xong.
  async save(userId: string, plan: MealPlanResponseDto): Promise<boolean> {
    try {
      const daily = plan.daily_target;
      await this.plans.insert({
        id: plan.plan_id,
        user_id: userId,
        target_calories: daily.target_calories,
        source: plan.source ?? null,
        bmi: daily?.bmi ?? null,
        bmr: daily?.bmr ?? null,
        tdee: daily?.tdee ?? null,
        protein_g: daily?.protein_g ?? null,
        carbs_g: daily?.carbs_g ?? null,
        fat_g: daily?.fat_g ?? null,
        day_count: plan.days?.length ?? 3,
        plan_json: plan,
        created_at: new Date(),
      });

      // Lưu chi tiết từng món ăn và bài tập thể dục dưới dạng bảng quan hệ dễ đọc
      await this.savePlanBreakdown(plan);

      return true;
    } catch {
      // A completed day-3 receipt can be replayed after a lost HTTP response.
      // Never overwrite an existing cycle (it may already contain later swaps).
      try {
        if (await this.plans.existsBy({ id: plan.plan_id, user_id: userId }))
          return true;
      } catch {
        /* DB unavailable */
      }
      this.logger.error('Không lưu được kế hoạch vào lịch sử.');
      return false;
    }
  }

  async saveUserProfile(userId: string, profile: object): Promise<boolean> {
    try {
      const allowed = [
        'age',
        'gender',
        'height_cm',
        'weight_kg',
        'activity_level',
        'goal',
        'pregnant_or_breastfeeding',
      ];
      const raw = profile as Record<string, unknown>;
      const sanitized: Record<string, unknown> = {};
      for (const key of allowed) {
        if (raw[key] !== undefined && raw[key] !== null) sanitized[key] = raw[key];
      }

      const age = typeof sanitized.age === 'number' ? sanitized.age : null;
      const gender = typeof sanitized.gender === 'string' ? sanitized.gender : null;
      const height = typeof sanitized.height_cm === 'number' ? sanitized.height_cm : null;
      const weight = typeof sanitized.weight_kg === 'number' ? sanitized.weight_kg : null;
      const goal = typeof sanitized.goal === 'string' ? sanitized.goal : null;
      const activity = typeof sanitized.activity_level === 'string' ? sanitized.activity_level : null;
      const bmi = (weight && height) ? Math.round((weight / ((height / 100) ** 2)) * 10) / 10 : null;

      await this.plans.manager
        .getRepository('users')
        .update(
          { id: userId },
          {
            profile_json: JSON.stringify(sanitized),
            age,
            gender,
            height_cm: height,
            weight_kg: weight,
            bmi,
            goal,
            activity_level: activity,
          },
        );
      return true;
    } catch {
      return false;
    }
  }

  // Đổi món/đổi bài/feedback ngày 1–2 cập nhật plan đã lưu (BRD FR-7, v2.5.0). plan_id của người khác,
  // hoặc plan tạo lúc chưa đăng nhập → không có dòng nào khớp, bỏ qua. Chỉ trả false khi DB lỗi.
  async update(userId: string, plan: MealPlanResponseDto): Promise<boolean> {
    try {
      const daily = plan.daily_target;
      await this.plans.update(
        { id: plan.plan_id, user_id: userId },
        {
          plan_json: plan,
          target_calories: daily.target_calories,
          source: plan.source ?? null,
          bmi: daily?.bmi ?? null,
          bmr: daily?.bmr ?? null,
          tdee: daily?.tdee ?? null,
          protein_g: daily?.protein_g ?? null,
          carbs_g: daily?.carbs_g ?? null,
          fat_g: daily?.fat_g ?? null,
          day_count: plan.days?.length ?? 3,
        },
      );
      await this.savePlanBreakdown(plan);
      return true;
    } catch {
      this.logger.error('Không cập nhật được kế hoạch trong lịch sử.');
      return false;
    }
  }

  private async savePlanBreakdown(plan: MealPlanResponseDto): Promise<void> {
    try {
      const mealRepo = this.plans.manager.getRepository(PlanMealItem);
      const workoutRepo = this.plans.manager.getRepository(PlanWorkoutItem);

      await mealRepo.delete({ plan_id: plan.plan_id });
      await workoutRepo.delete({ plan_id: plan.plan_id });

      const mealRows: Partial<PlanMealItem>[] = [];
      const workoutRows: Partial<PlanWorkoutItem>[] = [];
      const now = new Date();

      for (const day of plan.days || []) {
        for (const meal of day.meals || []) {
          const ingredientStr = meal.ingredients
            ?.map((i) => `${i.name} (${i.amount}${i.unit})`)
            .join(', ');
          mealRows.push({
            plan_id: plan.plan_id,
            day_number: day.day_number,
            meal_type: meal.meal_type,
            meal_name: meal.name,
            portion: meal.portion || null,
            calories: meal.calories,
            protein_g: meal.protein_g ?? null,
            carbs_g: meal.carbs_g ?? null,
            fat_g: meal.fat_g ?? null,
            ingredient_summary: ingredientStr || null,
            created_at: now,
          });
        }

        if (day.workout) {
          for (const ex of day.workout.exercises || []) {
            workoutRows.push({
              plan_id: plan.plan_id,
              day_number: day.day_number,
              workout_title: day.workout.title || null,
              exercise_name: ex.name,
              sets: ex.sets ?? null,
              reps_or_duration: ex.reps_or_duration || null,
              muscle_group: ex.muscle_group || null,
              created_at: now,
            });
          }
        }
      }

      if (mealRows.length > 0) {
        await mealRepo.insert(mealRows);
      }
      if (workoutRows.length > 0) {
        await workoutRepo.insert(workoutRows);
      }
    } catch (err) {
      this.logger.warn(`Không lưu được chi tiết món/bài tập: ${String(err)}`);
    }
  }

  async list(userId: string): Promise<PlanHistoryResponseDto> {
    const records = await this.plans.find({
      select: { id: true, created_at: true, target_calories: true },
      where: { user_id: userId },
      order: { created_at: 'DESC', id: 'DESC' },
      take: HISTORY_LIMIT,
    });
    return {
      plans: records.map((record) => ({
        id: record.id,
        created_at: record.created_at.toISOString(),
        target_calories: record.target_calories,
      })),
    };
  }

  // Plan của người khác trả 404 giống plan không tồn tại, để không lộ là id đó có thật.
  async findOne(userId: string, planId: string): Promise<MealPlanResponseDto> {
    const record = await this.plans.findOne({
      select: { id: true, plan_json: true },
      where: { id: planId, user_id: userId },
    });
    if (!record)
      throw new NotFoundException(
        'Không tìm thấy kế hoạch này trong lịch sử của bạn.',
      );
    return record.plan_json;
  }
}
