# F05 — Feedback cuối ngày (`FeedbackService`, BRD FR-5, PLAN 4.4)

## Feature

Ba câu trả lời (D2): cường độ, tình trạng cơ thể (chọn nhiều), ăn uống.

- **Ngày 1–2:** điều chỉnh **ngày kế tiếp**, giữ `plan_id`.
- **Ngày 3:** tạo plan 3 ngày **mới** (`plan_id` mới) có tính tới feedback (FR-5.3).

**Buổi tập — quy tắc cố định** (`adjustWorkout()`, không cần Gemini), theo thứ tự ưu tiên:

| Điều kiện | Tác động lên buổi tập ngày kế tiếp |
|---|---|
| `danger_sign` | Thay cả buổi bằng "Nghỉ ngơi — chỉ đi bộ nhẹ nếu thấy khoẻ". **Bỏ qua mọi quy tắc khác, kể cả ăn uống** (#14). `safety_warning.message` khuyên ngừng tập, hỏi ý kiến bác sĩ, gọi 115 nếu nặng |
| `joint_pain` | Thay động tác có tag `jumping`/`kneeling` bằng động tác cùng nhóm cơ trong kho (tránh cả chấn thương đã khai); không có thì bỏ |
| `hard` hoặc `fatigued` | Mỗi động tác −1 hiệp (còn ít nhất 1); thời lượng ×0,75 (ít nhất 10 phút) |
| `sore` | Động tác cùng nhóm cơ với ngày vừa tập: −1 hiệp (không cộng dồn với dòng trên); thêm 1 động tác giãn cơ (tối đa 8 động tác) |
| `easy` và chỉ có `normal` | Mỗi động tác +1 hiệp (tối đa 6) |
| Còn lại | Giữ nguyên |
| Hết động tác | Đi bộ nhẹ |

`normal` đi cùng trạng thái khác thì bị bỏ; `body_states` trùng thì bỏ trùng (BRD 6.4).

**Ăn uống** (quyết định Q3):

- `on_plan` → không gọi Gemini.
- `over` / `under` → Gemini lập lại 3 bữa của ngày kế tiếp:
  - ăn nhiều → nhắm `max(90% mục tiêu, BMR)`, tổng ngày phải trong `[cận dưới của plan; mục tiêu]`;
  - ăn ít → giữ mục tiêu, không ăn bù.

  Kết quả phải qua `findPlanViolations()` (khoảng calo, macro, không trùng món với các ngày khác) và không chứa nguyên liệu dị ứng. Không có khoá, hoặc Gemini hỏng cả 2 lần → giữ món cũ, thêm cảnh báo `mealsNotRebalanced`.
- Mức 90% và "không ăn bù" là suy ra từ quyết định Q3, ghi ở hằng `OVER_EATING_FACTOR`, nên đổi được dễ dàng.

**Ngày 3:** gọi `PlanService.generatePlan(profile, { feedbackNote })`. `feedbackNote` là câu tóm tắt dựng từ mã cố định (không có chữ người dùng nhập), Gemini nhận nó trong prompt. Sau đó áp quy tắc bài tập cho ngày 1 của plan mới. Plan mới là thực đơn mẫu mà người dùng báo ăn không đúng thực đơn → thêm `mealsNotRebalanced`.

**Gửi feedback hai lần cho cùng một ngày sẽ cộng dồn điều chỉnh** (brainstorm F6). Server không lưu trạng thái nên không phát hiện được; app phải khoá nút sau khi gửi (giai đoạn 7, F07 ghi vào PLAN).

## Scope

API:

- `backend_api/src/plan/adjust/workout-rules.ts` + `workout-rules.spec.ts` (mới)
- `backend_api/src/plan/adjust/feedback.service.ts` + `feedback.service.spec.ts` (mới)

## Implementation

### API Routes

Route `POST /api/v1/feedback` nối ở F06.

**Độ trễ:**

| Trường hợp | Độ trễ |
|---|---|
| Ngày 1–2, `on_plan` hoặc không có khoá | ~4 ms (đo khi lập plan) |
| Ngày 1–2, có cân đối món ăn | bằng thời gian gọi Gemini: 2–5 giây, tệ nhất 30 giây rồi giữ món cũ |
| Ngày 3 | bằng `generate-plan`: tệ nhất ~30 giây |

**Khoá API bên ngoài:** như F03 (log `(lần N, cân đối món ăn)` / `(lần N, tạo kế hoạch)`).

### UI Components

Không có (bảng feedback làm lại ở giai đoạn 7).

### DB / KV Changes

Không có. Ngày 3 lưu plan mới vào lịch sử ở controller (F06).

### Ràng buộc áp dụng

- **#13** ngày ăn nhẹ hơn không bao giờ dưới BMR — kiểm bằng code, có test.
- **#14** dấu hiệu nguy hiểm có `describe` riêng trong cả hai file test. Không gọi Gemini, không đổi món.
- **#12** câu tóm tắt feedback chỉ dựng từ mã cố định.
- **#15**, **#17** như F03.
- **#16** feedback ngày 1–2 giữ `plan_id`, ngày 3 sinh `plan_id` mới.

## Definition of Done

- [ ] `npm test` → `Test Files  24 passed (24)`, `Tests  240 passed (240)`
- [ ] `workout-rules.spec.ts`: 15 test (3 test dấu hiệu nguy hiểm); `feedback.service.spec.ts`: 9 test (2 test dấu hiệu nguy hiểm)
- [ ] All API routes complete within deployment timeout — không Gemini ~4 ms; có Gemini tệ nhất 30 s
- [x] Auth check at top of each protected handler — guard tuỳ chọn ở F06

## Test Checklist

1. **@happy**: rất mệt → ngày 2 mỗi động tác −1 hiệp, ngày 1 và 3 giữ nguyên, `plan_id` giữ; ăn nhiều + Gemini → ngày 2 có 3 món mới, tổng 1460 kcal, prompt ghi "khoảng 1462 kcal, trong khoảng 1399–1624"
2. **@auth**: không áp dụng ở tầng service
3. **@timeout**: đường chung `generateWithRetry()`
4. **@partial-fail**: Gemini lập ngày dưới BMR (1280 < 1399) hoặc không nhẹ hơn (1700 > 1624) → 2 lần gọi → giữ món cũ + `mealsNotRebalanced`; không có khoá → giữ món + cảnh báo
5. **@token**: như F03
6. **@db**: không áp dụng (ngày 3 lưu mới ở F06)

Dấu hiệu nguy hiểm (#14): trả `safety_warning` (có số 115), ngày kế tiếp là ngày nghỉ, món ăn giữ nguyên dù chọn "ăn nhiều", Gemini **không** bị gọi; ghi đè cả "nhẹ nhàng" và các trạng thái khác; áp cả cho ngày 1 của plan mới khi feedback ngày 3.

## Tasks

### Task 1 — Quy tắc bài tập: test trước

`backend_api/src/plan/adjust/workout-rules.spec.ts`:

```ts
import type { WorkoutContentDto } from '../dto/plan-content.dto.js';
import { ExerciseTag, MuscleGroup } from '../enums/exercise.enum.js';
import { BodyState, Eating, Intensity } from '../enums/feedback.enum.js';
import { REST_WORKOUT, STRETCH_EXERCISE, WALK_EXERCISE } from '../exercise-presets.js';
import { adjustWorkout, describeFeedback, normalizeFeedback } from './workout-rules.js';

const workout = (): WorkoutContentDto => ({
  title: 'Chân và cơ lõi',
  duration_minutes: 20,
  exercises: [
    { name: 'Jumping Jacks (khởi động)', sets: 2, reps_or_duration: '30 giây', muscle_group: MuscleGroup.CARDIO, tags: [ExerciseTag.JUMPING] },
    { name: 'Squat tay không', sets: 3, reps_or_duration: '12-15 lần', muscle_group: MuscleGroup.LEGS, tags: [] },
    { name: 'Chống đẩy khuỵu gối', sets: 3, reps_or_duration: '10-12 lần', muscle_group: MuscleGroup.CHEST, tags: [ExerciseTag.KNEELING, ExerciseTag.WRIST_LOAD] },
    { name: 'Plank cẳng tay', sets: 6, reps_or_duration: '30 giây', muscle_group: MuscleGroup.CORE, tags: [] },
  ],
});
const feedback = (intensity: Intensity, body_states: BodyState[], eating = Eating.ON_PLAN) =>
  normalizeFeedback({ intensity, body_states, eating });
const sets = (w: WorkoutContentDto) => w.exercises.map((exercise) => exercise.sets);
const NONE = new Set<MuscleGroup>();

describe('normalizeFeedback', () => {
  it('drops duplicates and ignores "normal" next to another state (BRD 6.4)', () => {
    expect([...normalizeFeedback({ intensity: Intensity.EASY, body_states: [BodyState.NORMAL, BodyState.SORE, BodyState.SORE], eating: Eating.ON_PLAN }).states])
      .toEqual([BodyState.SORE]);
    expect([...normalizeFeedback({ intensity: Intensity.EASY, body_states: [BodyState.NORMAL], eating: Eating.ON_PLAN }).states])
      .toEqual([BodyState.NORMAL]);
  });
});

describe('adjustWorkout — danger sign (#14, BRD FR-5.2)', () => {
  it('replaces the whole next workout with rest or a light walk', () => {
    expect(adjustWorkout(workout(), feedback(Intensity.MODERATE, [BodyState.DANGER_SIGN]), NONE, [])).toEqual(REST_WORKOUT);
  });

  it('overrides every other answer, including "easy" and other states', () => {
    const adjusted = adjustWorkout(
      workout(),
      feedback(Intensity.EASY, [BodyState.DANGER_SIGN, BodyState.SORE, BodyState.JOINT_PAIN, BodyState.NORMAL]),
      new Set([MuscleGroup.LEGS]),
      [],
    );
    expect(adjusted).toEqual(REST_WORKOUT);
  });

  it('returns a copy, so later edits cannot change the preset', () => {
    const adjusted = adjustWorkout(workout(), feedback(Intensity.HARD, [BodyState.DANGER_SIGN]), NONE, []);
    adjusted.exercises[0].sets = 5;
    expect(REST_WORKOUT.exercises[0].sets).toBe(1);
  });
});

describe('adjustWorkout — regular rules (BRD FR-5.2)', () => {
  it('keeps the workout for a moderate session with a normal body', () => {
    expect(adjustWorkout(workout(), feedback(Intensity.MODERATE, [BodyState.NORMAL]), NONE, [])).toEqual(workout());
  });

  it('adds one set after an easy session, capped at 6', () => {
    expect(sets(adjustWorkout(workout(), feedback(Intensity.EASY, [BodyState.NORMAL]), NONE, []))).toEqual([3, 4, 4, 6]);
  });

  it('does not add sets after an easy session when the body is not fine', () => {
    expect(sets(adjustWorkout(workout(), feedback(Intensity.EASY, [BodyState.FATIGUED]), NONE, []))).toEqual([1, 2, 2, 5]);
  });

  it.each([
    ['a hard session', feedback(Intensity.HARD, [BodyState.NORMAL])],
    ['fatigue', feedback(Intensity.MODERATE, [BodyState.FATIGUED])],
  ])('removes one set (at least 1 left) and shortens the session after %s', (_label, input) => {
    const adjusted = adjustWorkout(workout(), input, NONE, []);
    expect(sets(adjusted)).toEqual([1, 2, 2, 5]);
    expect(adjusted.duration_minutes).toBe(15);
  });

  it('eases muscle groups trained that day and adds a stretch when sore', () => {
    const adjusted = adjustWorkout(workout(), feedback(Intensity.MODERATE, [BodyState.SORE]), new Set([MuscleGroup.LEGS]), []);
    expect(sets(adjusted)).toEqual([2, 2, 3, 6, 1]);
    expect(adjusted.exercises.at(-1)?.name).toBe(STRETCH_EXERCISE.name);
  });

  it('does not stack the sore reduction on top of the tired one', () => {
    const adjusted = adjustWorkout(workout(), feedback(Intensity.HARD, [BodyState.SORE]), new Set([MuscleGroup.LEGS]), []);
    expect(sets(adjusted)).toEqual([1, 2, 2, 5, 1]);
  });

  it('replaces jumping and kneeling exercises on joint pain, respecting declared injuries', () => {
    const adjusted = adjustWorkout(workout(), feedback(Intensity.MODERATE, [BodyState.JOINT_PAIN]), NONE, [ExerciseTag.WRIST_LOAD]);
    const tags = adjusted.exercises.flatMap((exercise) => exercise.tags);
    expect(tags).not.toContain(ExerciseTag.JUMPING);
    expect(tags).not.toContain(ExerciseTag.KNEELING);
    expect(tags).not.toContain(ExerciseTag.WRIST_LOAD);
    expect(adjusted.exercises.map((exercise) => exercise.muscle_group)).toEqual([
      MuscleGroup.CARDIO,
      MuscleGroup.LEGS,
      MuscleGroup.CHEST,
      MuscleGroup.CORE,
    ]);
  });

  it('falls back to a walk when nothing is left', () => {
    const only: WorkoutContentDto = { ...workout(), exercises: [{ ...workout().exercises[0], name: 'Bật nhảy lạ', muscle_group: MuscleGroup.SHOULDERS, tags: [ExerciseTag.JUMPING] }] };
    const adjusted = adjustWorkout(only, feedback(Intensity.MODERATE, [BodyState.JOINT_PAIN]), NONE, [ExerciseTag.OVERHEAD, ExerciseTag.WRIST_LOAD]);
    expect(adjusted.exercises.length).toBeGreaterThan(0);
    expect(adjusted.exercises.every((exercise) => !exercise.tags.includes(ExerciseTag.JUMPING))).toBe(true);
    const empty = adjustWorkout({ ...workout(), exercises: [] }, feedback(Intensity.MODERATE, [BodyState.NORMAL]), NONE, []);
    expect(empty.exercises).toEqual([WALK_EXERCISE]);
  });

  it('never goes past 8 exercises when adding the stretch', () => {
    const full: WorkoutContentDto = {
      ...workout(),
      exercises: Array.from({ length: 8 }, (_, i) => ({ ...workout().exercises[1], name: `Động tác ${i}` })),
    };
    expect(adjustWorkout(full, feedback(Intensity.MODERATE, [BodyState.SORE]), NONE, []).exercises).toHaveLength(8);
  });
});

describe('describeFeedback', () => {
  it('builds the note only from fixed labels', () => {
    expect(describeFeedback(feedback(Intensity.HARD, [BodyState.SORE, BodyState.JOINT_PAIN], Eating.OVER))).toBe(
      'buổi tập rất mệt; căng mỏi cơ; đau khớp; ăn nhiều hơn thực đơn',
    );
  });
});
```

```bash
cd backend_api
npx vitest run src/plan/adjust/workout-rules.spec.ts   # đỏ: Cannot find module './workout-rules.js'
```

`backend_api/src/plan/adjust/workout-rules.ts`:

```ts
import type { ExerciseContentDto, WorkoutContentDto } from '../dto/plan-content.dto.js';
import { ExerciseTag, type MuscleGroup } from '../enums/exercise.enum.js';
import { BodyState, Eating, Intensity } from '../enums/feedback.enum.js';
import { REST_WORKOUT, STRETCH_EXERCISE, WALK_EXERCISE } from '../exercise-presets.js';
import { exerciseCandidates, exerciseLevel, toPlanExercise } from '../swap-pools.js';
import { normalizeKey } from '../text.util.js';

// Quy tắc cố định cho buổi tập ngày kế tiếp sau feedback (BRD FR-5.2, D2) — không cần Gemini.

export const MAX_SETS = 6;
export const MAX_EXERCISES = 8;
const MIN_DURATION_MINUTES = 10;
const TIRED_DURATION_FACTOR = 0.75;
// Đau khớp → bỏ bật nhảy và chống quỳ (BRD FR-5.2).
const JOINT_PAIN_TAGS = [ExerciseTag.JUMPING, ExerciseTag.KNEELING];

export interface NormalizedFeedback {
  intensity: Intensity;
  states: Set<BodyState>;
  eating: Eating;
}

// Bỏ trùng; `normal` đi cùng trạng thái khác thì bị bỏ qua (BRD 6.4).
export function normalizeFeedback(input: { intensity: Intensity; body_states: BodyState[]; eating: Eating }): NormalizedFeedback {
  const states = new Set(input.body_states);
  if (states.size > 1) states.delete(BodyState.NORMAL);
  return { intensity: input.intensity, states, eating: input.eating };
}

export function hasDangerSign(feedback: NormalizedFeedback): boolean {
  return feedback.states.has(BodyState.DANGER_SIGN);
}

// Thứ tự ưu tiên: dấu hiệu nguy hiểm (thay cả buổi, bỏ qua mọi quy tắc khác — #14) → đau khớp → rất mệt/uể oải
// → căng mỏi cơ → nhẹ nhàng. Giảm không cộng dồn: một động tác giảm tối đa 1 hiệp.
export function adjustWorkout(
  workout: WorkoutContentDto,
  feedback: NormalizedFeedback,
  trainedMuscles: Set<MuscleGroup>,
  profileAvoidTags: ExerciseTag[],
): WorkoutContentDto {
  if (hasDangerSign(feedback)) return structuredClone(REST_WORKOUT);

  let exercises = workout.exercises.map((exercise) => ({ ...exercise, tags: [...exercise.tags] }));
  let durationMinutes = workout.duration_minutes;

  if (feedback.states.has(BodyState.JOINT_PAIN)) {
    exercises = replaceJointLoading(exercises, profileAvoidTags);
  }

  const tired = feedback.intensity === Intensity.HARD || feedback.states.has(BodyState.FATIGUED);
  if (tired) {
    exercises = exercises.map((exercise) => ({ ...exercise, sets: Math.max(1, exercise.sets - 1) }));
    durationMinutes = Math.max(MIN_DURATION_MINUTES, Math.round(durationMinutes * TIRED_DURATION_FACTOR));
  }

  if (feedback.states.has(BodyState.SORE)) {
    if (!tired) {
      exercises = exercises.map((exercise) =>
        trainedMuscles.has(exercise.muscle_group) ? { ...exercise, sets: Math.max(1, exercise.sets - 1) } : exercise,
      );
    }
    const hasStretch = exercises.some((exercise) => normalizeKey(exercise.name) === normalizeKey(STRETCH_EXERCISE.name));
    if (!hasStretch && exercises.length < MAX_EXERCISES) exercises.push({ ...STRETCH_EXERCISE, tags: [] });
  }

  const allNormal = [...feedback.states].every((state) => state === BodyState.NORMAL);
  if (feedback.intensity === Intensity.EASY && allNormal) {
    exercises = exercises.map((exercise) => ({ ...exercise, sets: Math.min(MAX_SETS, exercise.sets + 1) }));
  }

  if (exercises.length === 0) exercises = [{ ...WALK_EXERCISE, tags: [] }];
  return { ...workout, duration_minutes: durationMinutes, exercises };
}

function replaceJointLoading(exercises: ExerciseContentDto[], profileAvoidTags: ExerciseTag[]): ExerciseContentDto[] {
  const names = new Set(exercises.map((exercise) => normalizeKey(exercise.name)));
  return exercises.flatMap((exercise): ExerciseContentDto[] => {
    if (!exercise.tags.some((tag) => JOINT_PAIN_TAGS.includes(tag))) return [exercise];
    const [candidate] = exerciseCandidates(exercise.muscle_group, {
      avoidTags: [...JOINT_PAIN_TAGS, ...profileAvoidTags],
      excludeNames: names,
      maxLevel: exerciseLevel(exercise.name) ?? 3,
    });
    if (!candidate) return [];
    names.add(normalizeKey(candidate.name));
    return [toPlanExercise(candidate, exercise.sets)];
  });
}

const INTENSITY_NOTE: Record<Intensity, string> = {
  [Intensity.EASY]: 'buổi tập nhẹ nhàng',
  [Intensity.MODERATE]: 'buổi tập vừa sức',
  [Intensity.HARD]: 'buổi tập rất mệt',
};
const STATE_NOTE: Record<BodyState, string> = {
  [BodyState.NORMAL]: 'cơ thể bình thường',
  [BodyState.SORE]: 'căng mỏi cơ',
  [BodyState.JOINT_PAIN]: 'đau khớp',
  [BodyState.FATIGUED]: 'uể oải, thiếu ngủ',
  [BodyState.DANGER_SIGN]: 'có dấu hiệu chóng mặt, khó thở hoặc đau ngực',
};
const EATING_NOTE: Record<Eating, string> = {
  [Eating.ON_PLAN]: 'ăn đúng thực đơn',
  [Eating.OVER]: 'ăn nhiều hơn thực đơn',
  [Eating.UNDER]: 'ăn ít hơn thực đơn hoặc bỏ bữa',
};

// Câu tóm tắt feedback cho prompt tạo plan mới (FR-5.3). Chỉ dựng từ mã cố định, không có chữ người dùng nhập.
export function describeFeedback(feedback: NormalizedFeedback): string {
  return [INTENSITY_NOTE[feedback.intensity], ...[...feedback.states].map((state) => STATE_NOTE[state]), EATING_NOTE[feedback.eating]].join('; ');
}
```

```bash
npx vitest run src/plan/adjust/workout-rules.spec.ts   # Tests  15 passed (15)
```

### Task 2 — `FeedbackService`: test trước

`backend_api/src/plan/adjust/feedback.service.spec.ts`:

```ts
import { geminiAnswering, geminiOff, makeProfile, samplePlan } from '../../../test/plan-fixtures.js';
import type { FeedbackDto } from '../dto/adjust-plan.dto.js';
import type { MealPlanResponseDto } from '../dto/meal-plan-response.dto.js';
import { ExerciseTag } from '../enums/exercise.enum.js';
import { BodyState, Eating, Intensity } from '../enums/feedback.enum.js';
import { REST_WORKOUT } from '../exercise-presets.js';
import type { GeminiService } from '../gemini.service.js';
import { PlanService } from '../plan.service.js';
import { SAFETY_WARNING_MESSAGE, WARNINGS } from '../plan-warnings.js';
import { FeedbackService } from './feedback.service.js';

const dayTotal = (plan: MealPlanResponseDto, index: number) => plan.days[index].meals.reduce((sum, meal) => sum + meal.calories, 0);

// 3 bữa cho mục tiêu 1624 kcal (BMR 1399); macro chia 25/50/25 nên luôn khớp calo. Mỗi bữa nằm trong khoảng
// của nó (sáng 244–568, trưa/tối 406–731), nên ca nào bị loại là do đúng tổng ngày.
const macros = (calories: number) => ({ protein_g: (calories * 0.25) / 4, carbs_g: (calories * 0.5) / 4, fat_g: (calories * 0.25) / 9 });
const rebalancedDay = (breakfast: number, lunch: number, dinner: number) => ({
  meals: [
    { meal_type: 'breakfast', name: 'Cháo yến mạch táo', portion: '1 bát', calories: breakfast, ...macros(breakfast), ingredients: [{ name: 'Yến mạch', amount: 50, unit: 'g', category: 'pantry' }] },
    { meal_type: 'lunch', name: 'Cơm gạo lứt, gà hấp gừng', portion: '1 chén + 1 đĩa', calories: lunch, ...macros(lunch), ingredients: [{ name: 'Gạo lứt', amount: 90, unit: 'g', category: 'pantry' }] },
    { meal_type: 'dinner', name: 'Canh rau củ đậu phụ non', portion: '1 bát lớn + 1 chén cơm', calories: dinner, ...macros(dinner), ingredients: [{ name: 'Đậu phụ non', amount: 150, unit: 'g', category: 'protein' }] },
  ],
});
const lighterDay = () => rebalancedDay(360, 560, 540); // 1460

describe('FeedbackService', () => {
  let plan: MealPlanResponseDto;

  beforeAll(async () => {
    plan = await samplePlan();
  });

  afterEach(() => vi.restoreAllMocks());

  const service = (gemini: GeminiService = geminiOff) => new FeedbackService(gemini, new PlanService(geminiOff));
  const request = (overrides: Partial<FeedbackDto> = {}): FeedbackDto =>
    ({ profile: makeProfile(), plan, day_number: 1, intensity: Intensity.MODERATE, body_states: [BodyState.NORMAL], eating: Eating.ON_PLAN, ...overrides }) as FeedbackDto;

  it('adjusts only the next day, keeps plan_id and returns no safety warning', async () => {
    const { response, isNewPlan } = await service().apply(request({ intensity: Intensity.HARD }));
    expect(isNewPlan).toBe(false);
    expect(response.safety_warning).toBeNull();
    expect(response.plan.plan_id).toBe(plan.plan_id);
    expect(response.plan.days[1].workout.exercises.map((e) => e.sets)).toEqual(
      plan.days[1].workout.exercises.map((e) => Math.max(1, e.sets - 1)),
    );
    expect(response.plan.days[0]).toEqual(plan.days[0]);
    expect(response.plan.days[2]).toEqual(plan.days[2]);
  });

  describe('danger sign (#14, BRD FR-5.2)', () => {
    it('returns the safety warning and turns the next day into rest, leaving meals alone', async () => {
      const { gemini, generateJson } = geminiAnswering(lighterDay());
      const { response } = await service(gemini).apply(
        request({ day_number: 2, intensity: Intensity.EASY, body_states: [BodyState.DANGER_SIGN, BodyState.NORMAL], eating: Eating.OVER }),
      );
      expect(response.safety_warning).toEqual({ message: SAFETY_WARNING_MESSAGE });
      expect(response.plan.days[2].workout).toMatchObject({ title: REST_WORKOUT.title, duration_minutes: 15 });
      expect(response.plan.days[2].workout.exercises).toHaveLength(1);
      expect(response.plan.days[2].meals).toEqual(plan.days[2].meals);
      expect(generateJson).not.toHaveBeenCalled();
      expect(response.plan.warnings).not.toContain(WARNINGS.mealsNotRebalanced);
    });

    it('also applies to the first day of the next plan', async () => {
      const { response, isNewPlan } = await service().apply(request({ day_number: 3, body_states: [BodyState.DANGER_SIGN] }));
      expect(isNewPlan).toBe(true);
      expect(response.safety_warning).not.toBeNull();
      expect(response.plan.days[0].workout.title).toBe(REST_WORKOUT.title);
    });
  });

  describe('eating (decision Q3)', () => {
    it('does not call Gemini when the user ate as planned', async () => {
      const { gemini, generateJson } = geminiAnswering(lighterDay());
      await service(gemini).apply(request());
      expect(generateJson).not.toHaveBeenCalled();
    });

    it('keeps the meals and says so when there is no Gemini key', async () => {
      const { response } = await service().apply(request({ eating: Eating.OVER }));
      expect(response.plan.days[1].meals).toEqual(plan.days[1].meals);
      expect(response.plan.warnings).toContain(WARNINGS.mealsNotRebalanced);
    });

    it('lets Gemini lighten the next day after over-eating, never below BMR (#13)', async () => {
      const { gemini, generateJson } = geminiAnswering(lighterDay());
      const { response } = await service(gemini).apply(request({ eating: Eating.OVER }));
      expect(generateJson).toHaveBeenCalledTimes(1);
      expect(String(generateJson.mock.calls[0][0])).toContain('Tổng calo của ngày khoảng 1462 kcal, trong khoảng 1399–1624');
      expect(response.plan.days[1].meals.map((meal) => meal.meal_id)).toEqual(['m2_1', 'm2_2', 'm2_3']);
      expect(dayTotal(response.plan, 1)).toBe(1460);
      expect(response.plan.warnings).not.toContain(WARNINGS.mealsNotRebalanced);
    });

    it.each([
      ['below BMR (1280 < 1399)', rebalancedDay(300, 500, 480)],
      ['not lighter than the normal target (1700 > 1624)', rebalancedDay(500, 620, 580)],
    ])('rejects a rebalanced day %s, then keeps the old meals', async (_label, bad) => {
      const { gemini, generateJson } = geminiAnswering(bad, bad);
      const { response } = await service(gemini).apply(request({ eating: Eating.OVER }));
      expect(generateJson).toHaveBeenCalledTimes(2);
      expect(response.plan.days[1].meals).toEqual(plan.days[1].meals);
      expect(response.plan.warnings).toContain(WARNINGS.mealsNotRebalanced);
    });
  });

  describe('day 3 → new plan (FR-5.3)', () => {
    it('creates a new plan with a new id and applies the workout rules to its first day', async () => {
      const generatePlan = vi.spyOn(PlanService.prototype, 'generatePlan');
      const { response, isNewPlan } = await service().apply(
        request({ day_number: 3, body_states: [BodyState.JOINT_PAIN], eating: Eating.UNDER }),
      );
      expect(isNewPlan).toBe(true);
      expect(response.plan.plan_id).not.toBe(plan.plan_id);
      expect(generatePlan).toHaveBeenCalledWith(expect.anything(), { feedbackNote: 'buổi tập vừa sức; đau khớp; ăn ít hơn thực đơn hoặc bỏ bữa' });
      const tags = response.plan.days[0].workout.exercises.flatMap((exercise) => exercise.tags);
      expect(tags).not.toContain(ExerciseTag.JUMPING);
      expect(tags).not.toContain(ExerciseTag.KNEELING);
      expect(response.plan.warnings).toContain(WARNINGS.mealsNotRebalanced);
    });
  });
});
```

```bash
npx vitest run src/plan/adjust/feedback.service.spec.ts   # đỏ: Cannot find module './feedback.service.js'
```

`backend_api/src/plan/adjust/feedback.service.ts`:

```ts
import { Injectable, Logger } from '@nestjs/common';
import { Type } from 'class-transformer';
import { ArrayMaxSize, ArrayMinSize, IsArray, ValidateNested } from 'class-validator';
import type { FeedbackDto, FeedbackResponseDto } from '../dto/adjust-plan.dto.js';
import type { MealPlanResponseDto } from '../dto/meal-plan-response.dto.js';
import { type DayContentDto, MealContentDto } from '../dto/plan-content.dto.js';
import type { MuscleGroup } from '../enums/exercise.enum.js';
import { Eating } from '../enums/feedback.enum.js';
import { PlanSource } from '../enums/plan-source.enum.js';
import { GeminiService } from '../gemini.service.js';
import { generateWithRetry } from '../gemini-retry.js';
import { assemblePlan, MEAL_ORDER } from '../plan-assembly.js';
import { dayCalorieBounds, findPlanViolations, parseContent } from '../plan-validation.js';
import { PlanService } from '../plan.service.js';
import { SAFETY_WARNING_MESSAGE, WARNINGS } from '../plan-warnings.js';
import { findRestrictionViolations } from '../restriction-filter.js';
import { matchRestrictions } from '../restriction-matcher.js';
import { buildDayMealsPrompt } from './adjust-prompts.js';
import { type ClientPlanContext, readClientPlan, rebuildPlan } from './client-plan.js';
import { adjustWorkout, describeFeedback, hasDangerSign, normalizeFeedback, type NormalizedFeedback } from './workout-rules.js';

// Ăn nhiều hơn → ngày kế tiếp nhắm 90% mục tiêu, không dưới BMR (#13); ăn ít → giữ mục tiêu, không ăn bù.
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
  response: FeedbackResponseDto;
  // Feedback ngày 3 tạo plan mới (FR-5.3): lịch sử lưu mới thay vì cập nhật.
  isNewPlan: boolean;
}

@Injectable()
export class FeedbackService {
  private readonly logger = new Logger(FeedbackService.name);

  constructor(
    private readonly gemini: GeminiService,
    private readonly planService: PlanService,
  ) {}

  async apply(dto: FeedbackDto): Promise<FeedbackResult> {
    const context = readClientPlan(dto.profile, dto.plan);
    const feedback = normalizeFeedback(dto);
    const safety_warning = hasDangerSign(feedback) ? { message: SAFETY_WARNING_MESSAGE } : null;
    const trainedMuscles = new Set(
      context.plan.days[dto.day_number - 1].workout.exercises.map((exercise) => exercise.muscle_group),
    );

    if (dto.day_number === 3) {
      const plan = await this.nextPlan(context, feedback, trainedMuscles);
      return { response: { plan, safety_warning }, isNewPlan: true };
    }

    const nextIndex = dto.day_number;
    const days: DayContentDto[] = context.plan.days.map((day) => ({ meals: day.meals, workout: day.workout }));
    days[nextIndex] = {
      ...days[nextIndex],
      workout: adjustWorkout(days[nextIndex].workout, feedback, trainedMuscles, context.match.avoidTags),
    };

    const extra: string[] = [];
    // Dấu hiệu nguy hiểm: không tự điều chỉnh gì ngoài buổi tập (#14).
    if (!hasDangerSign(feedback) && feedback.eating !== Eating.ON_PLAN) {
      const meals = await this.rebalanceMeals(context, days, nextIndex, feedback.eating);
      if (meals) days[nextIndex] = { ...days[nextIndex], meals };
      else extra.push(WARNINGS.mealsNotRebalanced);
    }
    return { response: { plan: rebuildPlan(context, days, extra), safety_warning }, isNewPlan: false };
  }

  // FR-5.3: plan 3 ngày mới có tính tới feedback (Gemini nhận câu tóm tắt), rồi áp quy tắc bài tập cho ngày 1.
  private async nextPlan(
    context: ClientPlanContext,
    feedback: NormalizedFeedback,
    trainedMuscles: Set<MuscleGroup>,
  ): Promise<MealPlanResponseDto> {
    const next = await this.planService.generatePlan(context.profile, { feedbackNote: describeFeedback(feedback) });
    const avoidTags = matchRestrictions(context.profile.restrictions).avoidTags;
    const days: DayContentDto[] = next.days.map((day, index) => ({
      meals: day.meals,
      workout: index === 0 ? adjustWorkout(day.workout, feedback, trainedMuscles, avoidTags) : day.workout,
    }));
    const warnings = [...next.warnings];
    if (next.source === PlanSource.SAMPLE && feedback.eating !== Eating.ON_PLAN && !hasDangerSign(feedback)) {
      warnings.push(WARNINGS.mealsNotRebalanced);
    }
    return assemblePlan({ days }, next.daily_target, next.source, warnings, next.plan_id);
  }

  // Gemini lập lại 3 bữa của ngày kế tiếp (quyết định Q3). Không có khoá hoặc Gemini hỏng 2 lần → null, giữ món cũ.
  private async rebalanceMeals(
    context: ClientPlanContext,
    days: DayContentDto[],
    dayIndex: number,
    eating: Exclude<Eating, Eating.ON_PLAN>,
  ): Promise<MealContentDto[] | null> {
    if (!this.gemini.isConfigured) return null;
    const { target } = context;
    const planRange = dayCalorieBounds(target);
    const dayCalories =
      eating === Eating.OVER ? Math.max(Math.round(target.target_calories * OVER_EATING_FACTOR), target.bmr) : target.target_calories;
    const range = eating === Eating.OVER ? { min: planRange.min, max: target.target_calories } : planRange;
    const otherNames = days.flatMap((day, index) => (index === dayIndex ? [] : day.meals.map((meal) => meal.name)));

    return generateWithRetry(
      this.logger,
      'cân đối món ăn',
      () =>
        this.gemini.generateJson(
          buildDayMealsPrompt(context.profile, target.target_calories, dayIndex + 1, dayCalories, range, eating, otherNames),
        ),
      (raw) => {
        const parsed = parseContent(DayMealsDto, raw);
        if (!parsed.value) return { value: null, errors: parsed.errors };
        const meals = [...parsed.value.meals].sort((a, b) => MEAL_ORDER.indexOf(a.meal_type) - MEAL_ORDER.indexOf(b.meal_type));
        const candidateDays = days.map((day, index) => (index === dayIndex ? { ...day, meals } : day));
        const total = meals.reduce((sum, meal) => sum + meal.calories, 0);
        const errors = [
          ...findPlanViolations({ days: candidateDays }, target),
          ...(total <= range.max ? [] : [`Ngày ${dayIndex + 1}: tổng ${total} kcal vượt ${range.max}`]),
          ...findRestrictionViolations([candidateDays[dayIndex]], context.match),
        ];
        return errors.length > 0 ? { value: null, errors } : { value: meals, errors: [] };
      },
    );
  }
}
```

```bash
npx vitest run src/plan/adjust/feedback.service.spec.ts   # Tests  9 passed (9)
```

### Task 3 — Cổng kiểm tra F05

```bash
cd backend_api
npm run typecheck
npm test            # Test Files  24 passed (24) · Tests  240 passed (240)
```
