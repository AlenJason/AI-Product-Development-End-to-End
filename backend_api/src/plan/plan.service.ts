import { Injectable, Logger } from '@nestjs/common';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { CreatePlanDto } from './dto/create-plan.dto.js';
import { GeminiService } from './gemini.service.js';
import { ACTIVITY_MULTIPLIER } from './enums/activity-level.enum.js';
import { GOAL_CALORIE_ADJUSTMENT } from './enums/goal.enum.js';
import { Gender } from './enums/gender.enum.js';
import type { DailyTarget, MealPlanResponse } from './interfaces/plan.interface.js';
import { isNutritionWithinBounds } from './nutrition-sanity.util.js';

const SAMPLE_PLAN_PATH = fileURLToPath(
  new URL('./data/sample-plan.json', import.meta.url),
);

@Injectable()
export class PlanService {
  private readonly logger = new Logger(PlanService.name);

  constructor(private readonly gemini: GeminiService) {}

  async generatePlan(dto: CreatePlanDto): Promise<MealPlanResponse> {
    const dailyTarget = this.computeDailyTarget(dto);

    if (!this.gemini.isConfigured) {
      this.logger.warn(
        'GEMINI_API_KEY chưa cấu hình — trả về sample_plan.json dự phòng (BRD NFR-2).',
      );
      return this.loadSamplePlan(dailyTarget);
    }

    // NFR-4: validate số liệu AI trả về, retry tối đa 1 lần, cuối cùng rơi về sample_plan.json.
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const plan = await this.gemini.generatePlan(dto, dailyTarget);
        if (isNutritionWithinBounds(plan)) {
          return plan;
        }
        this.logger.warn(
          `Gemini trả về calo ngoài khoảng hợp lý (lần thử ${attempt + 1}), đang thử lại...`,
        );
      } catch (error) {
        this.logger.error('Lỗi khi gọi Gemini API', error as Error);
      }
    }

    this.logger.warn('Rơi về sample_plan.json dự phòng sau khi retry thất bại.');
    return this.loadSamplePlan(dailyTarget);
  }

  // FR-1.5: BMI, BMR (Mifflin-St Jeor), TDEE = BMR × hệ số hoạt động (FR-1.2), calo mục tiêu theo goal (FR-1.3).
  computeDailyTarget(dto: CreatePlanDto): DailyTarget {
    const bmr =
      dto.gender === Gender.MALE
        ? 10 * dto.weight_kg + 6.25 * dto.height_cm - 5 * dto.age + 5
        : 10 * dto.weight_kg + 6.25 * dto.height_cm - 5 * dto.age - 161;

    const tdee = bmr * ACTIVITY_MULTIPLIER[dto.activity_level];
    const targetCalories = Math.round(tdee + GOAL_CALORIE_ADJUSTMENT[dto.goal]);

    // Macro mặc định cho MVP: protein 25%, carbs 45%, fat 30% tổng calo mục tiêu.
    return {
      target_calories: targetCalories,
      protein_g: Math.round((targetCalories * 0.25) / 4),
      carbs_g: Math.round((targetCalories * 0.45) / 4),
      fat_g: Math.round((targetCalories * 0.3) / 9),
    };
  }

  private loadSamplePlan(dailyTarget: DailyTarget): MealPlanResponse {
    const raw = readFileSync(SAMPLE_PLAN_PATH, 'utf-8');
    const plan = JSON.parse(raw) as MealPlanResponse;
    return { ...plan, daily_target: dailyTarget };
  }
}
