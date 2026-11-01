import {
  Inject,
  Injectable,
  Logger,
  UnprocessableEntityException,
  ConflictException,
  ServiceUnavailableException,
  ForbiddenException,
} from '@nestjs/common';
import { createHash, randomUUID } from 'node:crypto';
import { DataSource } from 'typeorm';
import { FeedbackReceipt } from '../../database/entities/feedback-receipt.entity.js';
import { PlanRecord } from '../../database/entities/plan-record.entity.js';
import { PLAN_AI, type PlanAi, taskSourceWarning } from '../ai-provider.js';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  ValidateNested,
} from 'class-validator';
import type { FeedbackDto } from '../dto/adjust-plan.dto.js';
import { MealPlanResponseDto } from '../dto/meal-plan-response.dto.js';
import { safeFeedbackWorkout } from './feedback-workout.js';
import { MealContentDto, type DayContentDto } from '../dto/plan-content.dto.js';
import type { MuscleGroup } from '../enums/exercise.enum.js';
import { Eating } from '../enums/feedback.enum.js';
import { PlanSource } from '../enums/plan-source.enum.js';
import { generateWithRetry } from '../gemini-retry.js';
import { assemblePlan, MEAL_ORDER } from '../plan-assembly.js';
import {
  dayCalorieBounds,
  findPlanViolations,
  parseContent,
} from '../plan-validation.js';
import { PlanService } from '../plan.service.js';
import { SAFETY_WARNING_MESSAGE, WARNINGS } from '../plan-warnings.js';
import { findRestrictionViolations } from '../restriction-filter.js';
import { matchRestrictions } from '../restriction-matcher.js';
import { buildDayMealsPrompt } from './adjust-prompts.js';
import {
  type ClientPlanContext,
  readClientPlan,
  rebuildPlan,
} from './client-plan.js';
import {
  adjustWorkout,
  describeFeedback,
  hasDangerSign,
  normalizeFeedback,
  type NormalizedFeedback,
} from './workout-rules.js';

export const OVER_EATING_FACTOR = 0.9;

class DayMealsDto {
  @IsArray()
  @ArrayMinSize(3)
  @ArrayMaxSize(3)
  @ValidateNested({ each: true })
  @Type(() => MealContentDto)
  meals: MealContentDto[];
}

export interface FeedbackResult {
  replayed?: boolean;
  response: {
    plan: MealPlanResponseDto;
    safety_warning: { message: string } | null;
  };
  isNewPlan: boolean;
}

@Injectable()
export class FeedbackService {
  private readonly logger = new Logger(FeedbackService.name);

  constructor(
    @Inject(PLAN_AI) private readonly ai: PlanAi,
    private readonly planService: PlanService,
    private readonly database?: DataSource,
  ) {}

  private readonly pending = new Map<
    string,
    { hash: string; owner: string | null; work: Promise<FeedbackResult> }
  >();
  private readonly completed = new Map<
    string,
    { until: number; result: FeedbackResult }
  >();

  async apply(
    dto: FeedbackDto,
    owner: string | null = null,
  ): Promise<FeedbackResult> {
    readClientPlan(dto.profile, dto.plan);
    const normal = normalizeFeedback(dto);
    const hash = createHash('sha256')
      .update(stableJson({ ...dto, body_states: [...normal.states].sort() }))
      .digest('hex');
    const key = `${dto.plan.plan_id}:${dto.day_number}`;
    for (const [id, entry] of this.completed)
      if (entry.until <= Date.now()) this.completed.delete(id);
    const cached = this.database
      ? undefined
      : this.completed.get(`${key}:${hash}:${owner ?? ''}`);
    if (cached) return structuredClone(cached.result);
    const active = this.pending.get(key);
    if (active) {
      if (active.hash !== hash || active.owner !== owner)
        throw new ConflictException(
          'Ngày này đang xử lý một phản hồi khác. Không gửi lại nội dung khác.',
        );
      const result = structuredClone(await active.work);
      return this.database ? { ...result, replayed: true } : result;
    }
    const work = this.database
      ? this.applyDurably(dto, hash, owner)
      : this.applyOnce(dto);
    this.pending.set(key, { hash, owner, work });
    try {
      const result = await work;
      if (this.completed.size >= 100)
        this.completed.delete(this.completed.keys().next().value!);
      if (!this.database)
        this.completed.set(`${key}:${hash}:${owner ?? ''}`, {
          until: Date.now() + 300_000,
          result: structuredClone(result),
        });
      return result;
    } finally {
      this.pending.delete(key);
    }
  }

  private async applyDurably(
    dto: FeedbackDto,
    hash: string,
    owner: string | null,
  ): Promise<FeedbackResult> {
    const db = this.database!,
      repo = db.getRepository(FeedbackReceipt),
      token = randomUUID(),
      now = Date.now();
    const savedPlan = await db
      .getRepository(PlanRecord)
      .findOneBy({ id: dto.plan.plan_id });
    if (savedPlan && savedPlan.user_id !== owner)
      throw new ForbiddenException('Kế hoạch thuộc tài khoản khác.');
    // Atomic primary-key claim, no DB transaction held across an AI call.
    try {
      await db.query(
        'INSERT OR IGNORE INTO feedback_receipts (plan_id,day_number,owner_id,request_hash,status,token,lease_until,result_json) VALUES (?,?,?,?,?,?,?,NULL)',
        [
          dto.plan.plan_id,
          dto.day_number,
          owner,
          hash,
          'processing',
          token,
          now + 600_000,
        ],
      );
    } catch {
      throw new ServiceUnavailableException(
        'Không thể lưu phản hồi. Kế hoạch hiện tại chưa thay đổi; vui lòng thử lại.',
      );
    }
    const key = { plan_id: dto.plan.plan_id, day_number: dto.day_number };
    const row = await repo.findOneByOrFail(key);
    if (row.request_hash !== hash || row.owner_id !== owner)
      throw new ConflictException(
        'Phản hồi cho ngày này đã tồn tại với nội dung khác. Kế hoạch hiện tại không bị điều chỉnh lần nữa.',
      );
    if (row.status === 'completed' && row.result_json)
      return { ...structuredClone(row.result_json), replayed: true };
    if (row.token !== token) {
      if (row.lease_until > now)
        throw new ConflictException(
          'Phản hồi đang được xử lý. Vui lòng giữ nội dung và thử lại sau.',
        );
      const claim = await repo
        .createQueryBuilder()
        .update()
        .set({ token, lease_until: now + 600_000 })
        .where(
          'plan_id=:plan AND day_number=:day AND status=:status AND token=:previous AND lease_until<=:now',
          {
            plan: key.plan_id,
            day: key.day_number,
            status: 'processing',
            previous: row.token,
            now,
          },
        )
        .execute();
      if (claim.affected !== 1)
        throw new ConflictException(
          'Phản hồi đang được xử lý. Vui lòng thử lại sau.',
        );
    }
    try {
      const result = await this.applyOnce(dto);
      const saved = await repo.update(
        { ...key, token, status: 'processing' },
        { status: 'completed', result_json: result, lease_until: 0 },
      );
      if (saved.affected !== 1)
        throw new ConflictException(
          'Phiên xử lý phản hồi đã thay đổi. Vui lòng thử lại cùng nội dung.',
        );
      return result;
    } catch (error) {
      try {
        await repo.delete({ ...key, token, status: 'processing' });
      } catch {
        /* Keep fenced claim if DB is unavailable. */
      }
      if (
        error instanceof ConflictException ||
        error instanceof UnprocessableEntityException
      )
        throw error;
      throw new ServiceUnavailableException(
        'Không thể hoàn tất lưu phản hồi. Kế hoạch hiện tại được giữ nguyên; hãy thử lại cùng nội dung.',
      );
    }
  }

  private async applyOnce(dto: FeedbackDto): Promise<FeedbackResult> {
    const context = readClientPlan(dto.profile, dto.plan);
    const feedback = normalizeFeedback(dto);
    const safety_warning = hasDangerSign(feedback)
      ? { message: SAFETY_WARNING_MESSAGE }
      : null;
    const trainedMuscles = new Set<MuscleGroup>(
      context.plan.days[dto.day_number - 1].workout.exercises.map(
        (exercise) => exercise.muscle_group,
      ),
    );

    if (dto.day_number === 3) {
      const plan = await this.nextPlan(context, feedback, trainedMuscles);
      return { response: { plan, safety_warning }, isNewPlan: true };
    }

    const nextIndex = dto.day_number;
    const days: DayContentDto[] = context.plan.days.map((day) => ({
      meals: day.meals,
      workout: day.workout,
    }));
    days[nextIndex] = {
      ...days[nextIndex],
      workout: safeFeedbackWorkout(
        adjustWorkout(
          days[nextIndex].workout,
          feedback,
          trainedMuscles,
          context.match.avoidTags,
        ),
        context.profile,
        context.match.avoidTags,
      ),
    };

    const extra: string[] = [];
    if (!hasDangerSign(feedback) && feedback.eating !== Eating.ON_PLAN) {
      const meals = await this.rebalanceMeals(
        context,
        days,
        nextIndex,
        feedback.eating,
      );
      if (meals) days[nextIndex] = { ...days[nextIndex], meals };
      else extra.push(WARNINGS.mealsNotRebalanced);
      extra.push(...taskSourceWarning(this.ai, 'feedback-meals', !!meals));
    }
    return {
      response: {
        plan: this.checked(rebuildPlan(context, days, extra), context, [
          nextIndex,
        ]),
        safety_warning,
      },
      isNewPlan: false,
    };
  }

  private checked(
    plan: MealPlanResponseDto,
    context: ClientPlanContext,
    indexes: number[],
  ): MealPlanResponseDto {
    const errors = [
      ...parseContent(MealPlanResponseDto, plan).errors,
      ...findPlanViolations(plan, context.target),
      ...findRestrictionViolations(
        plan.days.filter((_, i) => indexes.includes(i)),
        context.match,
      ),
    ];
    if (errors.length)
      throw new UnprocessableEntityException(
        'Điều chỉnh không đạt kiểm tra kế hoạch hoặc hạn chế. Kế hoạch cũ được giữ nguyên.',
      );
    return plan;
  }

  private async nextPlan(
    context: ClientPlanContext,
    feedback: NormalizedFeedback,
    trainedMuscles: Set<MuscleGroup>,
  ): Promise<MealPlanResponseDto> {
    const options = {
      feedbackNote: describeFeedback(feedback),
      ...(hasDangerSign(feedback) ? { skipGemini: true } : {}),
    };
    const next = await this.planService.generatePlan(context.profile, options);
    if (
      this.ai.providerName === 'groq' &&
      !hasDangerSign(feedback) &&
      next.source === PlanSource.SAMPLE
    ) {
      throw new UnprocessableEntityException(
        'Groq chưa tạo được chu kỳ mới hợp lệ. Kế hoạch hiện tại được giữ nguyên; vui lòng thử lại.',
      );
    }
    const avoidTags = matchRestrictions(context.profile.restrictions).avoidTags;
    const days: DayContentDto[] = next.days.map((day, index) => ({
      meals: day.meals,
      workout:
        index === 0
          ? safeFeedbackWorkout(
              adjustWorkout(day.workout, feedback, trainedMuscles, avoidTags),
              context.profile,
              avoidTags,
            )
          : day.workout,
    }));
    const warnings = [...next.warnings];
    if (
      next.source === PlanSource.SAMPLE &&
      feedback.eating !== Eating.ON_PLAN &&
      !hasDangerSign(feedback)
    ) {
      warnings.push(WARNINGS.mealsNotRebalanced);
    }
    return this.checked(
      assemblePlan(
        { days },
        next.daily_target,
        next.source,
        warnings,
        next.plan_id,
      ),
      context,
      [0, 1, 2],
    );
  }

  private async rebalanceMeals(
    context: ClientPlanContext,
    days: DayContentDto[],
    dayIndex: number,
    eating: Exclude<Eating, Eating.ON_PLAN>,
  ): Promise<MealContentDto[] | null> {
    if (!this.ai.isConfigured) {
      this.logger.warn(
        JSON.stringify({
          event: 'ai_fallback',
          provider: this.ai.providerName ?? 'gemini',
          reason: 'NOT_CONFIGURED',
        }),
      );
      return null;
    }
    const { target } = context;
    const planRange = dayCalorieBounds(target);
    const dayCalories =
      eating === Eating.OVER
        ? Math.max(
            Math.round(target.target_calories * OVER_EATING_FACTOR),
            target.bmr,
          )
        : target.target_calories;
    const range =
      eating === Eating.OVER
        ? { min: planRange.min, max: target.target_calories }
        : planRange;
    const otherNames = days.flatMap((day, index) =>
      index === dayIndex ? [] : day.meals.map((meal) => meal.name),
    );

    return generateWithRetry(
      this.logger,
      'cân đối món ăn',
      this.ai.budget,
      (timeoutMs) =>
        this.ai.generateJson(
          buildDayMealsPrompt(
            context.profile,
            target.target_calories,
            dayIndex + 1,
            dayCalories,
            range,
            eating,
            otherNames,
          ),
          timeoutMs,
        ),
      (raw) => {
        const parsed = parseContent(DayMealsDto, raw);
        if (!parsed.value) return { value: null, errors: parsed.errors };
        const meals = [...parsed.value.meals].sort(
          (a, b) =>
            MEAL_ORDER.indexOf(a.meal_type) - MEAL_ORDER.indexOf(b.meal_type),
        );
        const candidateDays = days.map((day, index) =>
          index === dayIndex ? { ...day, meals } : day,
        );
        const total = meals.reduce((sum, meal) => sum + meal.calories, 0);
        const errors = [
          ...findPlanViolations({ days: candidateDays }, target),
          ...(total <= range.max
            ? []
            : [`Ngày ${dayIndex + 1}: tổng ${total} kcal vượt ${range.max}`]),
          ...findRestrictionViolations(
            [candidateDays[dayIndex]],
            context.match,
          ),
        ];
        return errors.length > 0
          ? { value: null, errors }
          : { value: meals, errors: [] };
      },
      this.ai.providerName,
    );
  }
}

function stableJson(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(',')}]`;
  if (value !== null && typeof value === 'object')
    return `{${Object.entries(value)
      .filter(([, v]) => v !== undefined)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([k, v]) => `${JSON.stringify(k)}:${stableJson(v)}`)
      .join(',')}}`;
  return JSON.stringify(value) ?? 'null';
}
