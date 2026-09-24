import { BadRequestException, Injectable, Logger, UnprocessableEntityException } from '@nestjs/common';
import type { SwapExerciseDto } from '../dto/adjust-plan.dto.js';
import type { MealPlanResponseDto } from '../dto/meal-plan-response.dto.js';
import { type DayContentDto, ExerciseContentDto } from '../dto/plan-content.dto.js';
import { GeminiService } from '../gemini.service.js';
import { generateWithRetry } from '../gemini-retry.js';
import { parseContent } from '../plan-validation.js';
import { WARNINGS } from '../plan-warnings.js';
import { hasAvoidedTag } from '../restriction-matcher.js';
import { exerciseCandidates, exerciseLevel, EXERCISE_LEVELS, toPlanExercise } from '../swap-pools.js';
import { normalizeKey } from '../text.util.js';
import { buildExerciseSwapPrompt } from './adjust-prompts.js';
import { type ClientPlanContext, readClientPlan, rebuildPlan } from './client-plan.js';
import { pickOne, RandomSource } from './random-source.js';

// Động tác không có trong kho (do Gemini sinh) coi như khó nhất, nên mọi động tác trong kho đều "nhẹ hơn".
const UNKNOWN_LEVEL = EXERCISE_LEVELS.length + 1;

@Injectable()
export class ExerciseSwapService {
  private readonly logger = new Logger(ExerciseSwapService.name);

  constructor(
    private readonly gemini: GeminiService,
    private readonly random: RandomSource,
  ) {}

  async swap(dto: SwapExerciseDto): Promise<MealPlanResponseDto> {
    const context = readClientPlan(dto.profile, dto.plan);
    const [dayIndex, exerciseIndex] = parseExerciseId(dto.exercise_id);
    const original = context.plan.days[dayIndex]?.workout.exercises[exerciseIndex];
    if (!original) throw new BadRequestException(`exercise_id ${dto.exercise_id} không có trong plan`);

    const dayNames = new Set(context.plan.days[dayIndex].workout.exercises.map((exercise) => normalizeKey(exercise.name)));
    // "Nhẹ hơn" đo được bằng code: cùng nhóm cơ, không thêm hiệp, không thêm kiểu tải mới, không vướng chấn thương.
    const violations = (exercise: ExerciseContentDto): string[] => [
      ...(exercise.muscle_group === original.muscle_group ? [] : [`muscle_group phải là ${original.muscle_group}`]),
      ...(exercise.sets <= original.sets ? [] : [`sets không được quá ${original.sets}`]),
      ...(exercise.tags.every((tag) => original.tags.includes(tag)) ? [] : ['tags thêm kiểu tải mà động tác cũ không có']),
      ...(hasAvoidedTag(exercise, context.match.avoidTags) ? ['động tác không phù hợp chấn thương đã khai'] : []),
      ...(dayNames.has(normalizeKey(exercise.name)) ? [`động tác "${exercise.name}" đã có trong buổi tập`] : []),
    ];

    const fromGemini = await this.fromGemini(context, original, violations);
    const replacement = fromGemini ?? this.fromPool(context, original, dayNames, violations);
    if (!replacement) {
      throw new UnprocessableEntityException(
        'Không tìm được động tác nhẹ hơn cùng nhóm cơ phù hợp với bạn — động tác này có thể đã là mức nhẹ nhất.',
      );
    }
    const days: DayContentDto[] = context.plan.days.map((day, d) => ({
      ...day,
      workout: {
        ...day.workout,
        exercises: day.workout.exercises.map((existing, e) => (d === dayIndex && e === exerciseIndex ? replacement : existing)),
      },
    }));
    const extra = !fromGemini && context.match.hasUnrecognized ? [WARNINGS.restrictionsIncomplete] : [];
    return rebuildPlan(context, days, extra);
  }

  private async fromGemini(
    context: ClientPlanContext,
    original: ExerciseContentDto,
    violations: (exercise: ExerciseContentDto) => string[],
  ): Promise<ExerciseContentDto | null> {
    if (!this.gemini.isConfigured) return null;
    const names = context.plan.days.flatMap((day) => day.workout.exercises.map((exercise) => exercise.name));
    return generateWithRetry(
      this.logger,
      'đổi bài tập',
      this.gemini.budget,
      (timeoutMs) => this.gemini.generateJson(buildExerciseSwapPrompt(context.profile, original, names), timeoutMs),
      (raw) => {
        const parsed = parseContent(ExerciseContentDto, raw);
        if (!parsed.value) return parsed;
        const errors = violations(parsed.value);
        return errors.length > 0 ? { value: null, errors } : parsed;
      },
    );
  }

  // Kho động tác: mức khó thấp hơn động tác cũ; chọn ngẫu nhiên trong nhóm gần mức cũ nhất.
  private fromPool(
    context: ClientPlanContext,
    original: ExerciseContentDto,
    dayNames: Set<string>,
    violations: (exercise: ExerciseContentDto) => string[],
  ): ExerciseContentDto | null {
    const maxLevel = (exerciseLevel(original.name) ?? UNKNOWN_LEVEL) - 1;
    const candidates = exerciseCandidates(original.muscle_group, {
      avoidTags: context.match.avoidTags,
      excludeNames: dayNames,
      maxLevel,
    })
      .map((exercise) => ({ level: exercise.level, exercise: toPlanExercise(exercise, original.sets) }))
      .filter(({ exercise }) => violations(exercise).length === 0);
    const closest = candidates.filter((candidate) => candidate.level === candidates[0]?.level);
    return pickOne(closest, this.random)?.exercise ?? null;
  }
}

// "e2_3" → [1, 2]; định dạng đã được DTO kiểm.
function parseExerciseId(exerciseId: string): [number, number] {
  const [day, exercise] = exerciseId.slice(1).split('_').map(Number);
  return [day - 1, exercise - 1];
}
