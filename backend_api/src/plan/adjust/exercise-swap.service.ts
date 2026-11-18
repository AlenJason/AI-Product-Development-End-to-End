import {
  BadRequestException,
  Inject,
  Injectable,
  Logger,
  UnprocessableEntityException,
} from '@nestjs/common';
import { PLAN_AI, type PlanAi, taskSourceWarning } from '../ai-provider.js';
import type { SwapExerciseDto } from '../dto/adjust-plan.dto.js';
import type { MealPlanResponseDto } from '../dto/meal-plan-response.dto.js';
import {
  type DayContentDto,
  ExerciseContentDto,
} from '../dto/plan-content.dto.js';
import { generateWithRetry } from '../gemini-retry.js';
import { assessedExercise } from '../ai-exercise.js';
import { parseContent } from '../plan-validation.js';
import { WARNINGS } from '../plan-warnings.js';
import { hasAvoidedTag } from '../restriction-matcher.js';
import {
  exerciseCandidates,
  exerciseLevel,
  EXERCISE_LEVELS,
  toPlanExercise,
} from '../swap-pools.js';
import { normalizeKey } from '../text.util.js';
import { buildExerciseSwapPrompt } from './adjust-prompts.js';
import {
  type ClientPlanContext,
  readClientPlan,
  rebuildPlan,
} from './client-plan.js';
import { pickOne, RandomSource } from './random-source.js';
import {
  capSwapWorkload,
  swapExerciseProblems,
} from './exercise-swap-validation.js';

const UNKNOWN_LEVEL = EXERCISE_LEVELS.length + 1;

@Injectable()
export class ExerciseSwapService {
  private readonly logger = new Logger(ExerciseSwapService.name);

  constructor(
    @Inject(PLAN_AI) private readonly ai: PlanAi,
    private readonly random: RandomSource,
  ) {}

  async swap(dto: SwapExerciseDto): Promise<MealPlanResponseDto> {
    const context = readClientPlan(dto.profile, dto.plan);
    const [dayIndex, exerciseIndex] = parseExerciseId(dto.exercise_id);
    const original =
      context.plan.days[dayIndex]?.workout.exercises[exerciseIndex];
    if (!original)
      throw new BadRequestException(
        `exercise_id ${dto.exercise_id} không có trong plan`,
      );

    const dayNames = new Set(
      context.plan.days[dayIndex].workout.exercises.map((exercise) =>
        normalizeKey(exercise.name),
      ),
    );
    const violations = (
      exercise: ExerciseContentDto,
      assessedLevel?: number,
    ): string[] => [
      ...swapExerciseProblems(
        exercise,
        original,
        context.profile,
        assessedLevel,
      ),
      ...(exercise.muscle_group === original.muscle_group
        ? []
        : [`muscle_group phải là ${original.muscle_group}`]),
      ...(exercise.sets <= original.sets
        ? []
        : [`sets không được quá ${original.sets}`]),
      ...(exercise.tags.every((tag) => original.tags.includes(tag))
        ? []
        : ['tags thêm kiểu tải mà động tác cũ không có']),
      ...(hasAvoidedTag(exercise, context.match.avoidTags)
        ? ['động tác không phù hợp chấn thương đã khai']
        : []),
      ...(dayNames.has(normalizeKey(exercise.name))
        ? [`động tác "${exercise.name}" đã có trong buổi tập`]
        : []),
    ];

    const fromAi = await this.fromAi(context, original, violations);
    const replacement =
      fromAi ?? this.fromPool(context, original, dayNames, violations);
    if (!replacement) {
      throw new UnprocessableEntityException(
        'Không tìm được động tác nhẹ hơn cùng nhóm cơ phù hợp với bạn — động tác này có thể đã là mức nhẹ nhất.',
      );
    }

    const days: DayContentDto[] = context.plan.days.map((day, d) => ({
      ...day,
      workout: {
        ...day.workout,
        exercises: day.workout.exercises.map((existing, e) =>
          d === dayIndex && e === exerciseIndex ? replacement : existing,
        ),
      },
    }));
    const extra = [
      ...taskSourceWarning(this.ai, 'exercise-swap', !!fromAi),
      ...(!fromAi && context.match.hasUnrecognized
        ? [WARNINGS.restrictionsIncomplete]
        : []),
    ];
    return rebuildPlan(context, days, extra);
  }

  private async fromAi(
    context: ClientPlanContext,
    original: ExerciseContentDto,
    violations: (
      exercise: ExerciseContentDto,
      assessedLevel?: number,
    ) => string[],
  ): Promise<ExerciseContentDto | null> {
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
    const names = context.plan.days.flatMap((day) =>
      day.workout.exercises.map((exercise) => exercise.name),
    );
    return generateWithRetry(
      this.logger,
      'đổi bài tập',
      this.ai.budget,
      (timeoutMs) =>
        this.ai.generateJson(
          buildExerciseSwapPrompt(context.profile, original, names),
          timeoutMs,
        ),
      (raw) => {
        const assessed = assessedExercise(raw, context.profile);
        const parsed = parseContent(ExerciseContentDto, assessed.value);
        if (!parsed.value) return parsed;
        const errors = violations(parsed.value, assessed.level);
        return errors.length > 0 ? { value: null, errors } : parsed;
      },
      this.ai.providerName,
    );
  }

  private fromPool(
    context: ClientPlanContext,
    original: ExerciseContentDto,
    dayNames: Set<string>,
    violations: (
      exercise: ExerciseContentDto,
      assessedLevel?: number,
    ) => string[],
  ): ExerciseContentDto | null {
    const maxLevel = (exerciseLevel(original.name) ?? UNKNOWN_LEVEL) - 1;
    const candidates = exerciseCandidates(original.muscle_group, {
      avoidTags: context.match.avoidTags,
      excludeNames: dayNames,
      maxLevel,
    })
      .map((exercise) => ({
        level: exercise.level,
        exercise: capSwapWorkload(
          toPlanExercise(exercise, original.sets),
          original,
        ),
      }))
      .filter(({ exercise }) => violations(exercise).length === 0);
    const closest = candidates.filter(
      (candidate) => candidate.level === candidates[0]?.level,
    );
    return pickOne(closest, this.random)?.exercise ?? null;
  }
}

function parseExerciseId(exerciseId: string): [number, number] {
  const [day, exercise] = exerciseId.slice(1).split('_').map(Number);
  return [day - 1, exercise - 1];
}
