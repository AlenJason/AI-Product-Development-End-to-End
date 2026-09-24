import { Injectable, Logger } from '@nestjs/common';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import type { CreatePlanDto } from './dto/create-plan.dto.js';
import type { DailyTargetDto, MealPlanResponseDto } from './dto/meal-plan-response.dto.js';
import type { PlanContentDto } from './dto/plan-content.dto.js';
import { computeDailyTarget } from './daily-target.js';
import { PlanSource } from './enums/plan-source.enum.js';
import { GeminiService } from './gemini.service.js';
import { generateWithRetry } from './gemini-retry.js';
import { scaleMealsToTotal } from './meal-scaling.js';
import { assemblePlan } from './plan-assembly.js';
import { parsePlanContent, parsePlanStructure } from './plan-validation.js';
import { hasRestrictions, profileWarnings, WARNINGS } from './plan-warnings.js';
import { filterPlanByRestrictions, findRestrictionViolations } from './restriction-filter.js';
import { matchRestrictions, type RestrictionMatch } from './restriction-matcher.js';

const SAMPLE_PLAN_PATH = fileURLToPath(new URL('./data/sample-plan.json', import.meta.url));
const SAMPLE_CONTENT = loadSampleContent();

export interface GeneratePlanOptions {
  // Tóm tắt feedback ngày cuối của plan trước (FR-5.3), dựng từ mã cố định — không chứa chữ người dùng nhập.
  feedbackNote?: string;
}

@Injectable()
export class PlanService {
  private readonly logger = new Logger(PlanService.name);

  constructor(private readonly gemini: GeminiService) {}

  async generatePlan(profile: CreatePlanDto, options: GeneratePlanOptions = {}): Promise<MealPlanResponseDto> {
    const { target, flooredToBmr } = computeDailyTarget(profile);
    const warnings = profileWarnings(profile, flooredToBmr, target.bmr);
    const match = matchRestrictions(profile.restrictions);

    const content = await this.generateWithGemini(profile, target, match, options.feedbackNote);
    if (content) {
      return assemblePlan(content, target, PlanSource.GEMINI, warnings);
    }

    const sample = buildSampleContent(target, match);
    if (hasRestrictions(profile)) warnings.push(WARNINGS.sampleKeywordFiltered);
    if (match.hasUnrecognized || sample.incomplete) warnings.push(WARNINGS.restrictionsIncomplete);
    return assemblePlan(sample.plan, target, PlanSource.SAMPLE, warnings);
  }

  // Log chỉ ghi thông báo lỗi và vi phạm hợp đồng, không ghi request hay nội dung Gemini (NFR-7).
  private async generateWithGemini(
    profile: CreatePlanDto,
    target: DailyTargetDto,
    match: RestrictionMatch,
    feedbackNote: string | undefined,
  ): Promise<PlanContentDto | null> {
    if (!this.gemini.isConfigured) {
      this.logger.warn('GEMINI_API_KEY chưa cấu hình — dùng thực đơn mẫu (BRD NFR-2).');
      return null;
    }
    const content = await generateWithRetry(
      this.logger,
      'tạo kế hoạch',
      this.gemini.budget,
      (timeoutMs) => this.gemini.generatePlanContent(profile, target, feedbackNote, timeoutMs),
      (raw) => {
        const { plan, errors } = parsePlanContent(raw, target);
        if (!plan) return { value: null, errors };
        const violations = findRestrictionViolations(plan.days, match);
        return violations.length > 0 ? { value: null, errors: violations } : { value: plan, errors: [] };
      },
    );
    if (!content) this.logger.warn('Dùng thực đơn mẫu sau khi Gemini không trả được kết quả hợp lệ.');
    return content;
  }
}

// Thực đơn mẫu: lọc theo hạn chế đã nhận ra → nhân khẩu phần từng ngày cho khớp mục tiêu → kiểm đầy đủ.
// Soạn cho khoảng 1550 kcal/ngày; không nhân lên thì người có mục tiêu cao ăn dưới BMR (BRD NFR-4, v2.5.0).
export function buildSampleContent(
  target: DailyTargetDto,
  match: RestrictionMatch,
): { plan: PlanContentDto; incomplete: boolean } {
  const filtered = filterPlanByRestrictions(SAMPLE_CONTENT, match);
  const scaled = {
    days: filtered.plan.days.map((day) => ({ ...day, meals: scaleMealsToTotal(day.meals, target.target_calories) })),
  };
  const { plan, errors } = parsePlanContent(scaled, target);
  if (!plan) {
    throw new Error(`Thực đơn mẫu sau khi lọc và nhân khẩu phần không đạt hợp đồng: ${errors.join('; ')}`);
  }
  return { plan, incomplete: filtered.incomplete };
}

function loadSampleContent(): PlanContentDto {
  const { plan, errors } = parsePlanStructure(JSON.parse(readFileSync(SAMPLE_PLAN_PATH, 'utf-8')));
  if (!plan) {
    throw new Error(`sample-plan.json không đạt hợp đồng: ${errors.join('; ')}`);
  }
  return plan;
}
