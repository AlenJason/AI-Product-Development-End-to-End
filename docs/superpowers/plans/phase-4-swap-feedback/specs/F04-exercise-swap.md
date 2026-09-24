# F04 — Đổi bài tập (`ExerciseSwapService`, BRD FR-4.2, PLAN 4.3)

## Feature

Đổi một động tác sang động tác **nhẹ hơn**, **cùng nhóm cơ**, tránh chấn thương đã khai. Theo quyết định Q2: Gemini trước, kho dự phòng.

Không kiểm được "nhẹ hơn" theo nghĩa, nên kết quả Gemini phải qua các điều kiện **đo được bằng code**:

- cùng `muscle_group`;
- `sets` ≤ động tác cũ;
- `tags` ⊆ tag của động tác cũ (không thêm kiểu tải mới);
- không có tag vướng chấn thương mà bộ khớp nhận ra;
- không trùng động tác đã có trong buổi.

Sai → gọi lại 1 lần (không gọi lại nếu hết giờ) → kho.

**Kho** (`swap-exercises.json`): cùng nhóm cơ, `level` **thấp hơn** động tác cũ, qua cùng các điều kiện trên. Động tác không có trong kho (do Gemini sinh lúc tạo plan) được coi là khó nhất. Chọn ngẫu nhiên trong nhóm có mức khó gần động tác cũ nhất; số hiệp không vượt động tác cũ.

**Không còn động tác nào nhẹ hơn** (ví dụ "Chống đẩy tường", mức 1) → **422** "…động tác này có thể đã là mức nhẹ nhất."

## Scope

API:

- `backend_api/src/plan/adjust/exercise-swap.service.ts` + `exercise-swap.service.spec.ts` (mới)

## Implementation

### API Routes

Route `POST /api/v1/exercises/swap` nối ở F06.

**Độ trễ:**

| Đường | Độ trễ |
|---|---|
| Kho | ~4 ms (đo khi lập plan) |
| Gemini | 1–3 giây thường gặp (prompt ngắn); tệ nhất 30 giây, sau đó dùng kho |

**Khoá API bên ngoài:** như F03 (`generateJson()`, log `(lần N, đổi bài tập)`).

### UI Components

Không có (nút "Đổi bài" ở giai đoạn 7).

### DB / KV Changes

Không có.

### Ràng buộc áp dụng

- **#2** động tác mới qua `ExerciseContentDto` (`sets` 1–6, mã nhóm cơ/tag trong danh sách).
- **#12** thông báo vi phạm không nêu tag chấn thương.
- **#15** không gọi lại sau khi hết giờ.
- **#16** `exercise_id` giữ đúng vị trí.
- **#17** Gemini giả trong unit test.

## Definition of Done

- [ ] `npm test` → `Test Files  22 passed (22)`, `Tests  216 passed (216)`
- [ ] `exercise-swap.service.spec.ts`: 8 test
- [ ] All API routes complete within deployment timeout — kho ~4 ms, Gemini tệ nhất 30 s
- [x] Auth check at top of each protected handler — guard tuỳ chọn ở F06

## Test Checklist

1. **@happy**: "Squat tay không" (mức 2) → động tác chân mức 1, số hiệp ≤ 3, bữa ăn và `plan_id` giữ nguyên; có Gemini → dùng động tác Gemini đạt điều kiện
2. **@auth**: không áp dụng ở tầng service
3. **@timeout**: đường chung `generateWithRetry()` (test ở F01, F03)
4. **@partial-fail**: Gemini trả nhóm cơ khác / nhiều hiệp hơn / thêm tag `jumping` / trùng động tác → 2 lần gọi → kho mức 1; động tác đã nhẹ nhất → 422
5. **@token**: như F03
6. **@db**: không áp dụng

## Tasks

### Task 1 — Test trước

`backend_api/src/plan/adjust/exercise-swap.service.spec.ts`:

```ts
import { UnprocessableEntityException } from '@nestjs/common';
import { firstPick, geminiAnswering, geminiOff, makeProfile, samplePlan } from '../../../test/plan-fixtures.js';
import type { MealPlanResponseDto } from '../dto/meal-plan-response.dto.js';
import { ExerciseTag } from '../enums/exercise.enum.js';
import { exerciseLevel } from '../swap-pools.js';
import { ExerciseSwapService } from './exercise-swap.service.js';

// Plan mẫu không hạn chế: e1_2 = "Squat tay không" (legs, mức 2, 3 hiệp); e3_2 = "Chống đẩy tường" (chest, mức 1).
describe('ExerciseSwapService', () => {
  let plan: MealPlanResponseDto;

  beforeAll(async () => {
    plan = await samplePlan();
  });

  const swap = (service: ExerciseSwapService, exerciseId: string, profile = makeProfile()) =>
    service.swap({ profile, plan, exercise_id: exerciseId });

  describe('without Gemini (pool)', () => {
    it('picks a lighter exercise for the same muscle group and keeps everything else', async () => {
      const swapped = await swap(new ExerciseSwapService(geminiOff, firstPick), 'e1_2');
      const before = plan.days[0].workout.exercises[1];
      const after = swapped.days[0].workout.exercises[1];

      expect(before.name).toBe('Squat tay không');
      expect(after).toMatchObject({ exercise_id: 'e1_2', muscle_group: 'legs' });
      expect(exerciseLevel(after.name)).toBeLessThan(exerciseLevel(before.name) ?? 0);
      expect(after.sets).toBeLessThanOrEqual(before.sets);
      expect(swapped.plan_id).toBe(plan.plan_id);
      expect(swapped.days[0].meals).toEqual(plan.days[0].meals);
    });

    it('answers 422 when the exercise is already the lightest of its group', async () => {
      await expect(swap(new ExerciseSwapService(geminiOff, firstPick), 'e3_2')).rejects.toBeInstanceOf(UnprocessableEntityException);
    });

    it('never picks an exercise that loads a declared injury', async () => {
      const swapped = await swap(new ExerciseSwapService(geminiOff, firstPick), 'e1_1', makeProfile({}, { injuries: 'đau gối' }));
      expect(swapped.days[0].workout.exercises[0].tags).not.toContain(ExerciseTag.JUMPING);
    });
  });

  describe('with Gemini', () => {
    const lighterSquat = (overrides: object = {}) => ({
      name: 'Squat nửa biên độ dựa ghế',
      sets: 2,
      reps_or_duration: '10 lần',
      muscle_group: 'legs',
      tags: [],
      ...overrides,
    });

    it('uses a Gemini exercise that passes the measurable "lighter" checks', async () => {
      const { gemini, generateJson } = geminiAnswering(lighterSquat());
      const swapped = await swap(new ExerciseSwapService(gemini, firstPick), 'e1_2');
      expect(generateJson).toHaveBeenCalledTimes(1);
      expect(swapped.days[0].workout.exercises[1]).toMatchObject({ name: 'Squat nửa biên độ dựa ghế', sets: 2 });
    });

    it.each([
      ['another muscle group', lighterSquat({ muscle_group: 'chest' })],
      ['more sets than before', lighterSquat({ sets: 5 })],
      ['a new kind of load', lighterSquat({ tags: ['jumping'] })],
      ['an exercise already in the session', lighterSquat({ name: 'Plank cẳng tay' })],
    ])('rejects %s, then falls back to the pool', async (_label, bad) => {
      const { gemini, generateJson } = geminiAnswering(bad, bad);
      const swapped = await swap(new ExerciseSwapService(gemini, firstPick), 'e1_2');
      expect(generateJson).toHaveBeenCalledTimes(2);
      expect(exerciseLevel(swapped.days[0].workout.exercises[1].name)).toBe(1);
    });
  });
});
```

```bash
cd backend_api
npx vitest run src/plan/adjust/exercise-swap.service.spec.ts   # đỏ: Cannot find module './exercise-swap.service.js'
```

### Task 2 — Service

`backend_api/src/plan/adjust/exercise-swap.service.ts`:

```ts
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
      () => this.gemini.generateJson(buildExerciseSwapPrompt(context.profile, original, names)),
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
```

```bash
npx vitest run src/plan/adjust/exercise-swap.service.spec.ts   # Tests  8 passed (8)
```

### Task 3 — Cổng kiểm tra F04

```bash
cd backend_api
npm run typecheck
npm test            # Test Files  22 passed (22) · Tests  216 passed (216)
```
