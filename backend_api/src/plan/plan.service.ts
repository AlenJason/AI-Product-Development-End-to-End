import { Inject, Injectable, Logger, Optional } from '@nestjs/common';
import { PLAN_AI, type PlanAi } from './ai-provider.js';
import { prepareAiPlanExercises } from './ai-exercise.js';
import {
  ExerciseValidationError,
  type ExerciseDiagnostic,
} from './exercise-verification.js';
import {
  GroqPlanService,
  GroqRequestError,
  GroqContentError,
} from './groq-plan.service.js';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import type { CreatePlanDto } from './dto/create-plan.dto.js';
import type {
  DailyTargetDto,
  MealPlanResponseDto,
} from './dto/meal-plan-response.dto.js';
import type { PlanContentDto } from './dto/plan-content.dto.js';
import { computeDailyTarget } from './daily-target.js';
import { capWorkoutLevel, maxExerciseLevel } from './exercise-level.js';
import { PlanSource } from './enums/plan-source.enum.js';
import { generateWithRetry, MIN_RETRY_MS } from './gemini-retry.js';
import {
  safePlanIssues,
  type PlanValidationIssue,
} from './plan-diagnostics.js';
import { scaleMealsToTotal } from './meal-scaling.js';
import { assemblePlan } from './plan-assembly.js';
import { parsePlanContent, parsePlanStructure } from './plan-validation.js';
import { hasRestrictions, profileWarnings, WARNINGS } from './plan-warnings.js';
import {
  filterPlanByRestrictions,
  findRestrictionViolations,
  findRestrictionIssues,
} from './restriction-filter.js';
import {
  matchRestrictions,
  type RestrictionMatch,
} from './restriction-matcher.js';
import type { ExerciseLevel } from './swap-pools.js';

const SAMPLE_PLAN_PATH = fileURLToPath(
  new URL('./data/sample-plan.json', import.meta.url),
);
const SAMPLE_CONTENT = loadSampleContent();

export interface GeneratePlanOptions {
  // Tóm tắt feedback ngày cuối của plan trước (FR-5.3), dựng từ mã cố định — không chứa chữ người dùng nhập.
  feedbackNote?: string;
  // Dấu hiệu nguy hiểm ưu tiên an toàn (#14): tạo plan mẫu mà không gửi feedback tới Gemini.
  skipGemini?: boolean;
}

@Injectable()
export class PlanService {
  private readonly exerciseNotes = new WeakMap<object, ExerciseDiagnostic[]>();
  private readonly logger = new Logger(PlanService.name);

  constructor(
    @Inject(PLAN_AI) private readonly ai: PlanAi,
    @Optional() private readonly groq?: GroqPlanService,
  ) {}

  async generatePlan(
    profile: CreatePlanDto,
    options: GeneratePlanOptions = {},
  ): Promise<MealPlanResponseDto> {
    const { target, flooredToBmr } = computeDailyTarget(profile);
    const warnings = profileWarnings(profile, flooredToBmr, target.bmr);
    const match = matchRestrictions(profile.restrictions);
    const maxLevel = maxExerciseLevel(profile);

    const content = options.skipGemini
      ? null
      : await this.generateWithAi(profile, target, match, options.feedbackNote);
    if (content) {
      const notes = this.exerciseNotes.get(content) ?? [];
      if (notes.some((n) => n.action === 'replaced'))
        warnings.push(
          'Một số bài tập AI chưa xác minh được hoặc vượt giới hạn đã được thay bằng bài dự phòng đã kiểm tra.',
        );
      if (notes.some((n) => n.action === 'repaired'))
        warnings.push(
          'Metadata bài tập đã được đối chiếu và chuẩn hóa theo dữ liệu đã kiểm chứng.',
        );
      // Prompt đã ghi mức tối đa; động tác Gemini vẫn vượt mức thì thay bằng động tác trong kho, không gọi lại.
      return assemblePlan(
        capWorkoutLevel(content, maxLevel, match.avoidTags),
        target,
        this.groq?.enabled ? PlanSource.GROQ : PlanSource.GEMINI,
        warnings,
      );
    }

    const sample = buildSampleContent(target, match, maxLevel);
    if (hasRestrictions(profile)) warnings.push(WARNINGS.sampleKeywordFiltered);
    if (match.hasUnrecognized || sample.incomplete)
      warnings.push(WARNINGS.restrictionsIncomplete);
    return assemblePlan(sample.plan, target, PlanSource.SAMPLE, warnings);
  }

  // Log chỉ ghi thông báo lỗi và vi phạm hợp đồng, không ghi request hay nội dung Gemini (NFR-7).
  private async generateWithAi(
    profile: CreatePlanDto,
    target: DailyTargetDto,
    match: RestrictionMatch,
    feedbackNote: string | undefined,
  ): Promise<PlanContentDto | null> {
    if (this.groq?.enabled) {
      if (!this.groq.isConfigured) {
        this.logger.warn('GROQ_API_KEY chưa cấu hình — dùng thực đơn mẫu.');
        return null;
      }
      const deadline = Date.now() + this.groq.budget.totalMs;
      let repair: PlanValidationIssue[] = [];
      for (let attempt = 1; attempt <= 2; attempt++) {
        const remaining = deadline - Date.now();
        if (remaining <= 0 || (attempt > 1 && remaining < MIN_RETRY_MS)) break;
        const started = Date.now();
        let raw: unknown;
        const exerciseDiagnostics: ExerciseDiagnostic[] = [];
        try {
          raw = await this.groq.generatePlanContent(
            profile,
            target,
            feedbackNote,
            Math.min(remaining, this.groq.budget.perCallMs),
            repair,
          );
          const { plan, issues } = parsePlanContent(
            prepareAiPlanExercises(raw, profile, (diagnostic) => {
              exerciseDiagnostics.push(diagnostic);
              this.logger.warn(
                JSON.stringify({
                  event: 'exercise_validation',
                  provider: 'groq',
                  attempt,
                  ...diagnostic,
                }),
              );
            }),
            target,
          );
          repair = plan
            ? findRestrictionIssues(plan.days, match)
            : (issues ?? [
                {
                  validator: 'class-validator',
                  kind: 'schema',
                  code: 'SCHEMA',
                  path: '$',
                },
              ]);
          await this.groq.debugValidation?.(raw, {
            task: 'generate-plan',
            attempt,
            valid: !!plan && repair.length === 0,
            issues: safePlanIssues(repair),
            exercise_diagnostics: exerciseDiagnostics,
          });
          if (plan && repair.length === 0) {
            this.exerciseNotes.set(plan, exerciseDiagnostics);
            return plan;
          }
          this.logger.warn(
            JSON.stringify({
              event: 'plan_validation_failed',
              provider: 'groq',
              attempt,
              elapsed_ms: Date.now() - started,
              error_count: repair.length,
              issues: safePlanIssues(repair),
            }),
          );
        } catch (error) {
          await this.groq.debugValidation?.(raw, {
            task: 'generate-plan',
            attempt,
            valid: false,
            error: error instanceof Error ? error.message : 'Unknown error',
          });
          // Fixed categories only: even Error.name/message can echo private data.
          const timeout =
            error instanceof Error &&
            ['TimeoutError', 'AbortError'].includes(error.name);
          const code =
            error instanceof ExerciseValidationError
              ? error.error_code
              : error instanceof GroqContentError
                ? error.code
                : error instanceof GroqRequestError
                  ? 'HTTP_ERROR'
                  : timeout
                    ? 'TIMEOUT'
                    : 'TRANSPORT_OR_INTERNAL_ERROR';
          repair =
            error instanceof ExerciseValidationError
              ? [
                  {
                    validator: 'plan-rules',
                    kind: 'safety',
                    code: 'EXERCISE_VERIFICATION',
                    path: `days[${error.day_index}].workout.exercises[${error.exercise_index}]`,
                  },
                ]
              : error instanceof GroqContentError
                ? [
                    {
                      validator: 'groq-response',
                      kind: 'response',
                      code: error.code,
                      path: '$',
                    },
                  ]
                : [];
          this.logger.warn(
            JSON.stringify({
              event:
                error instanceof ExerciseValidationError
                  ? 'plan_validation_failed'
                  : 'plan_provider_failed',
              provider: 'groq',
              attempt,
              elapsed_ms: Date.now() - started,
              code,
              ...(error instanceof ExerciseValidationError
                ? error.diagnostic()
                : {}),
              ...(error instanceof GroqRequestError
                ? { status: error.status }
                : {}),
            }),
          );
          if (error instanceof GroqRequestError && error.status < 500) break;
          if (timeout) break;
        }
      }
      this.logger.warn(
        'Dùng thực đơn mẫu sau khi Groq không trả được kết quả hợp lệ.',
      );
      return null;
    }
    if (!this.ai.isConfigured) {
      this.logger.warn(
        'GEMINI_API_KEY chưa cấu hình — dùng thực đơn mẫu (BRD NFR-2).',
      );
      return null;
    }
    const content = await generateWithRetry(
      this.logger,
      'tạo kế hoạch',
      this.ai.budget,
      (timeoutMs) =>
        this.ai.generatePlanContent(profile, target, feedbackNote, timeoutMs),
      (raw) => {
        const { plan, errors } = parsePlanContent(
          prepareAiPlanExercises(raw, profile),
          target,
        );
        if (!plan) return { value: null, errors };
        const violations = findRestrictionViolations(plan.days, match);
        return violations.length > 0
          ? { value: null, errors: violations }
          : { value: plan, errors: [] };
      },
    );
    if (!content)
      this.logger.warn(
        'Dùng thực đơn mẫu sau khi Gemini không trả được kết quả hợp lệ.',
      );
    return content;
  }
}

// Thực đơn mẫu: lọc theo hạn chế đã nhận ra → hạ mức động tác theo hồ sơ → nhân khẩu phần từng ngày cho khớp
// mục tiêu → kiểm đầy đủ. Soạn cho khoảng 1550 kcal/ngày; không nhân lên thì người có mục tiêu cao ăn dưới BMR
// (BRD NFR-4, v2.5.0).
export function buildSampleContent(
  target: DailyTargetDto,
  match: RestrictionMatch,
  maxLevel: ExerciseLevel,
): { plan: PlanContentDto; incomplete: boolean } {
  const filtered = filterPlanByRestrictions(SAMPLE_CONTENT, match);
  const capped = capWorkoutLevel(filtered.plan, maxLevel, match.avoidTags);
  const scaled = {
    days: capped.days.map((day) => ({
      ...day,
      meals: scaleMealsToTotal(day.meals, target.target_calories),
    })),
  };
  const { plan, errors } = parsePlanContent(scaled, target);
  if (!plan) {
    throw new Error(
      `Thực đơn mẫu sau khi lọc và nhân khẩu phần không đạt hợp đồng: ${errors.join('; ')}`,
    );
  }
  return { plan, incomplete: filtered.incomplete };
}

function loadSampleContent(): PlanContentDto {
  const { plan, errors } = parsePlanStructure(
    JSON.parse(readFileSync(SAMPLE_PLAN_PATH, 'utf-8')),
  );
  if (!plan) {
    throw new Error(
      `sample-plan.json không đạt hợp đồng: ${errors.join('; ')}`,
    );
  }
  return plan;
}
