import { Injectable, Logger } from '@nestjs/common';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import type { CreatePlanDto } from './dto/create-plan.dto.js';
import type { DailyTargetDto, MealPlanResponseDto } from './dto/meal-plan-response.dto.js';
import type { PlanContentDto } from './dto/plan-content.dto.js';
import { computeDailyTarget } from './daily-target.js';
import { PlanSource } from './enums/plan-source.enum.js';
import { GeminiService, GeminiTimeoutError } from './gemini.service.js';
import { assemblePlan } from './plan-assembly.js';
import { parsePlanContent } from './plan-validation.js';
import { WARNINGS } from './plan-warnings.js';

const SAMPLE_PLAN_PATH = fileURLToPath(new URL('./data/sample-plan.json', import.meta.url));
const MAX_GEMINI_ATTEMPTS = 2;

@Injectable()
export class PlanService {
  private readonly logger = new Logger(PlanService.name);

  constructor(private readonly gemini: GeminiService) {}

  async generatePlan(profile: CreatePlanDto): Promise<MealPlanResponseDto> {
    const { target, flooredToBmr } = computeDailyTarget(profile);
    const warnings: string[] = [];
    if (flooredToBmr) warnings.push(WARNINGS.bmrFloor(target.bmr));
    if (profile.restrictions.health_conditions) warnings.push(WARNINGS.healthConditions);

    const content = await this.generateWithGemini(profile, target);
    if (content) {
      return assemblePlan(content, target, PlanSource.GEMINI, warnings);
    }

    if (hasRestrictions(profile)) warnings.push(WARNINGS.sampleNotFiltered);
    return assemblePlan(loadSampleContent(), target, PlanSource.SAMPLE, warnings);
  }

  // Log chỉ ghi thông báo lỗi và vi phạm hợp đồng, không ghi request hay nội dung Gemini (NFR-7).
  private async generateWithGemini(
    profile: CreatePlanDto,
    target: DailyTargetDto,
  ): Promise<PlanContentDto | null> {
    if (!this.gemini.isConfigured) {
      this.logger.warn('GEMINI_API_KEY chưa cấu hình — dùng thực đơn mẫu (BRD NFR-2).');
      return null;
    }

    for (let attempt = 1; attempt <= MAX_GEMINI_ATTEMPTS; attempt++) {
      try {
        const { plan, errors } = parsePlanContent(await this.gemini.generatePlanContent(profile, target));
        if (plan) return plan;
        this.logger.warn(`Kết quả Gemini không đạt hợp đồng (lần ${attempt}): ${errors.slice(0, 5).join('; ')}`);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        this.logger.error(`Lỗi khi gọi Gemini (lần ${attempt}): ${message}`);
        if (error instanceof GeminiTimeoutError) break;
      }
    }

    this.logger.warn('Dùng thực đơn mẫu sau khi Gemini không trả được kết quả hợp lệ.');
    return null;
  }
}

function hasRestrictions(profile: CreatePlanDto): boolean {
  const { allergies, injuries, health_conditions } = profile.restrictions;
  return Boolean(allergies || injuries || health_conditions);
}

function loadSampleContent(): PlanContentDto {
  const { plan, errors } = parsePlanContent(JSON.parse(readFileSync(SAMPLE_PLAN_PATH, 'utf-8')));
  if (!plan) {
    throw new Error(`sample-plan.json không đạt hợp đồng: ${errors.join('; ')}`);
  }
  return plan;
}
