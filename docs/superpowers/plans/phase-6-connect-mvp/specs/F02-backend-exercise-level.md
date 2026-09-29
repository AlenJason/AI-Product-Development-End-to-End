# F02 — Backend: độ khó động tác theo tuổi, mức vận động, thai kỳ (D6-A4)

## Feature

Trước đây mọi hồ sơ nhận cùng buổi tập ở chế độ giả lập — người 65 tuổi ít vận động cũng có Jumping Jacks. Nay mức khó tối đa theo hồ sơ (quyết định Q2; BRD FR-2.2 v2.6.0), dùng mức 1–3 có sẵn trong `data/swap-exercises.json`:

| Hồ sơ | Mức tối đa |
|---|---|
| Mang thai / cho con bú | 1 |
| ≥ 60 tuổi, hoặc ≥ 45 tuổi và ít vận động | 1 |
| Vận động nhiều và < 45 tuổi | 3 |
| Còn lại | 2 (thực đơn mẫu hiện có mức 1–2, nên giữ nguyên) |

Chỉ hạ mức, không tự nâng bài. Áp ở **mọi** đường ra động tác (#31):

| Đường | Cách áp |
|---|---|
| Thực đơn mẫu | `buildSampleContent(target, match, maxLevel)`: lọc chấn thương → `capWorkoutLevel()` → nhân khẩu phần |
| Kết quả Gemini khi tạo plan | `capWorkoutLevel()` sau khi kết quả qua kiểm hợp đồng — thay động tác vượt mức bằng động tác trong kho, **không gọi lại** Gemini |
| Prompt | `exerciseLevelRule()`: mức 1 → liệt kê động tác mức 1 trong kho; mức 2 → cấm các động tác mức 3 trong kho; mức 3 → không thêm dòng. Mang thai → `pregnancyRule()` (ngoài khối dữ liệu người dùng) |
| Đổi bài | kho: mức ≤ min(mức cũ − 1, mức hồ sơ); Gemini: động tác vượt mức bị coi là vi phạm → gọi lại / kho |
| Feedback đau khớp | động tác thay có mức ≤ mức hồ sơ |

`capWorkoutLevel()` tất định (ứng viên khó nhất còn hợp lệ, giữ số hiệp, tránh tag chấn thương). Động tác Gemini tự đặt (không có trong kho) chỉ bị coi là vượt mức khi giới hạn là 1 và có tag `jumping`. Nhóm cơ nào cũng có động tác mức 1 không tag (test khoá), nên hạ mức không làm rỗng buổi tập.

`ai_workspace/generate-plan-experiment.ts` thêm đúng dòng luật mà backend sinh cho hồ sơ thử nghiệm (mức 2) — prompt hai bên trùng từng dòng (27 dòng).

## Scope

API:

- `backend_api/src/plan/exercise-level.ts`, `exercise-level.spec.ts` (mới)
- `backend_api/src/plan/plan.service.ts`, `gemini.service.ts`, `adjust/adjust-prompts.ts`, `adjust/exercise-swap.service.ts`, `adjust/workout-rules.ts`, `adjust/feedback.service.ts` (sửa)
- `backend_api/src/plan/plan.service.spec.ts`, `sample-plan.spec.ts`, `gemini-prompt.spec.ts`, `adjust/exercise-swap.service.spec.ts`, `adjust/workout-rules.spec.ts` (sửa)
- `ai_workspace/generate-plan-experiment.ts` (sửa)

## Implementation

### API Routes

Không thêm route. **Độ trễ:** `capWorkoutLevel()` duyệt tối đa 3 × 8 động tác trong kho 39 động tác — không đáng kể. Không thêm lần gọi Gemini nào (vượt mức thì thay bằng kho).

**Khoá API bên ngoài:** prompt đổi một dòng → nên đo lại bằng khoá thật (`npm run build && npm run measure:gemini`, chạy tay, tốn khoảng 4 lần gọi trong hạn mức 20 lần/ngày — #9, #17). Chưa đo khi lập plan.

### UI Components

Không có.

### DB / KV Changes

Không có.

### Ràng buộc áp dụng

- **#15** không thêm lần gọi lại Gemini.
- **#17** test dùng Gemini giả.
- **#23** vẫn tránh tag chấn thương khi hạ mức.
- **#25** mỗi nhóm cơ có động tác mức 1 (nay còn đòi không có tag).
- Ràng buộc mới **#31** ghi vào wiki ở F06.

## Definition of Done

- [ ] `npm test` → `Tests  320 passed (320)`; `npm run test:e2e` → `Tests  74 passed (74)`, fixture không đổi
- [ ] `npm run typecheck`, `build`, `test:smoke`, `lint` sạch; `cd ai_workspace && npx tsc --noEmit` sạch
- [ ] Prompt `ai_workspace` trùng từng dòng với `buildPlanPrompt()` cho hồ sơ thử nghiệm

## Test Checklist

1. **@happy**: bảng `maxExerciseLevel` 10 hồ sơ; hồ sơ mặc định (mức 2) giữ nguyên thực đơn mẫu
2. **@elderly**: 65 tuổi ít vận động → mọi động tác mức 1, không `jumping`, cùng nhóm cơ, giữ số hiệp
3. **@gemini**: kết quả Gemini có động tác mức 2 cho người 60 tuổi → hạ mức, Gemini chỉ được gọi 1 lần
4. **@injury**: hạ mức vẫn tránh chấn thương — ca chỉ còn Bird-dog (quỳ gối) bị bỏ thay vì chọn
5. **@swap**: Gemini đề xuất "Lunge lùi" (mức 2) cho người 65 tuổi → bị từ chối 2 lần → 422
6. **@feedback**: đau khớp với giới hạn mức 1 → động tác thay đều mức 1
7. **@prompt**: dòng luật mức 1/mức 2/không có; luật mang thai nằm sau khối dữ liệu người dùng; prompt đổi bài có cùng luật
8. **@pregnancy**: mang thai → cảnh báo + mức 1
9. **@auth**, **@token**, **@db**: không đổi

## Tasks

### Task 1 — Mức tối đa và hạ mức

`backend_api/src/plan/exercise-level.ts`:

```ts
import type { CreatePlanDto } from './dto/create-plan.dto.js';
import type { DayContentDto, ExerciseContentDto, PlanContentDto } from './dto/plan-content.dto.js';
import { ActivityLevel } from './enums/activity-level.enum.js';
import { ExerciseTag } from './enums/exercise.enum.js';
import { WALK_EXERCISE } from './exercise-presets.js';
import { exerciseCandidates, exerciseLevel, type ExerciseLevel, toPlanExercise } from './swap-pools.js';
import { normalizeKey } from './text.util.js';

// Mức khó tối đa của động tác theo hồ sơ (BRD FR-2.2, v2.6.0; quyết định Q2 giai đoạn 6). Mức lấy từ
// `data/swap-exercises.json` (1 = nhẹ nhất). Chỉ hạ mức, không bao giờ tự nâng bài của người vận động nhiều.
export function maxExerciseLevel(
  profile: Pick<CreatePlanDto, 'age' | 'activity_level'> & { pregnant_or_breastfeeding?: boolean },
): ExerciseLevel {
  if (profile.pregnant_or_breastfeeding) return 1;
  if (profile.age >= 60 || (profile.age >= 45 && profile.activity_level === ActivityLevel.SEDENTARY)) return 1;
  if (profile.activity_level === ActivityLevel.ACTIVE && profile.age < 45) return 3;
  return 2;
}

// Động tác vượt mức cho phép. Động tác không có trong kho (Gemini tự đặt) không biết mức: chỉ coi là vượt khi
// giới hạn là 1 mà động tác có bật nhảy — mọi động tác mức 1 trong kho đều không bật nhảy.
export function exceedsLevel(exercise: ExerciseContentDto, maxLevel: ExerciseLevel): boolean {
  const level = exerciseLevel(exercise.name);
  if (level !== undefined) return level > maxLevel;
  return maxLevel === 1 && exercise.tags.includes(ExerciseTag.JUMPING);
}

// Thay động tác vượt mức bằng động tác trong kho cùng nhóm cơ, mức ≤ giới hạn, không vướng chấn thương,
// giữ số hiệp. Tất định (lấy ứng viên khó nhất còn hợp lệ) — dùng cho thực đơn mẫu và cả kết quả Gemini.
export function capWorkoutLevel(
  plan: PlanContentDto,
  maxLevel: ExerciseLevel,
  avoidTags: ExerciseTag[],
): PlanContentDto {
  const days = plan.days.map((day): DayContentDto => {
    const names = new Set(day.workout.exercises.map((exercise) => normalizeKey(exercise.name)));
    const exercises = day.workout.exercises.flatMap((exercise): ExerciseContentDto[] => {
      if (!exceedsLevel(exercise, maxLevel)) return [exercise];
      const [candidate] = exerciseCandidates(exercise.muscle_group, { avoidTags, excludeNames: names, maxLevel });
      if (!candidate) return [];
      names.add(normalizeKey(candidate.name));
      return [toPlanExercise(candidate, exercise.sets)];
    });
    return { ...day, workout: { ...day.workout, exercises: exercises.length > 0 ? exercises : [WALK_EXERCISE] } };
  });
  return { days };
}
```

`backend_api/src/plan/exercise-level.spec.ts`:

```ts
import type { PlanContentDto } from './dto/plan-content.dto.js';
import { ActivityLevel } from './enums/activity-level.enum.js';
import { ExerciseTag, MuscleGroup } from './enums/exercise.enum.js';
import { capWorkoutLevel, exceedsLevel, maxExerciseLevel } from './exercise-level.js';
import { buildSampleContent } from './plan.service.js';
import { matchRestrictions } from './restriction-matcher.js';
import { exerciseCandidates, exerciseLevel } from './swap-pools.js';

const levels = (plan: PlanContentDto) =>
  plan.days.flatMap((day) => day.workout.exercises.map((exercise) => exerciseLevel(exercise.name)));
const target = { bmi: 22, bmr: 1400, tdee: 1900, target_calories: 1900, protein_g: 119, carbs_g: 214, fat_g: 63 };
const restrictions = (injuries = '') => matchRestrictions({ allergies: '', injuries, health_conditions: '' });

describe('maxExerciseLevel (quyết định Q2 giai đoạn 6)', () => {
  it.each([
    [22, ActivityLevel.ACTIVE, false, 3],
    [44, ActivityLevel.ACTIVE, false, 3],
    [45, ActivityLevel.ACTIVE, false, 2],
    [22, ActivityLevel.LIGHT, false, 2],
    [22, ActivityLevel.SEDENTARY, false, 2],
    [44, ActivityLevel.SEDENTARY, false, 2],
    [45, ActivityLevel.SEDENTARY, false, 1],
    [59, ActivityLevel.LIGHT, false, 2],
    [60, ActivityLevel.ACTIVE, false, 1],
    [30, ActivityLevel.ACTIVE, true, 1],
  ])('%i tuổi, %s, mang thai %s → mức %i', (age, activity_level, pregnant_or_breastfeeding, expected) => {
    expect(maxExerciseLevel({ age, activity_level, pregnant_or_breastfeeding })).toBe(expected);
  });
});

describe('capWorkoutLevel', () => {
  it('keeps the sample plan unchanged up to level 2 (it only has levels 1–2)', () => {
    const { plan } = buildSampleContent(target, restrictions(), 2);
    expect(buildSampleContent(target, restrictions(), 3).plan).toEqual(plan);
    expect(Math.max(...levels(plan).map((level) => level ?? 0))).toBe(2);
  });

  it('replaces every level-2 exercise with a level-1 one of the same muscle group, keeping the sets', () => {
    const before = buildSampleContent(target, restrictions(), 3).plan;
    const { plan } = buildSampleContent(target, restrictions(), 1);
    expect(levels(plan).every((level) => level === 1)).toBe(true);
    plan.days.forEach((day, d) =>
      day.workout.exercises.forEach((exercise, e) => {
        expect(exercise.muscle_group).toBe(before.days[d].workout.exercises[e].muscle_group);
        expect(exercise.sets).toBe(before.days[d].workout.exercises[e].sets);
      }),
    );
    const tags = plan.days.flatMap((day) => day.workout.exercises.flatMap((exercise) => exercise.tags));
    expect(tags).not.toContain(ExerciseTag.JUMPING);
  });

  it('still avoids injury tags while lowering the level', () => {
    const { plan } = buildSampleContent(target, restrictions('Đau cổ tay'), 1);
    const tags = plan.days.flatMap((day) => day.workout.exercises.flatMap((exercise) => exercise.tags));
    expect(tags).not.toContain(ExerciseTag.WRIST_LOAD);
    expect(levels(plan).every((level) => level === 1)).toBe(true);
  });

  it('treats an unknown (Gemini) exercise as too hard only at level 1 with jumping', () => {
    const jump = { name: 'Nhảy bật cao tại chỗ', sets: 3, reps_or_duration: '20 lần', muscle_group: MuscleGroup.CARDIO, tags: [ExerciseTag.JUMPING] };
    const calm = { ...jump, name: 'Đứng thăng bằng một chân', muscle_group: MuscleGroup.CORE, tags: [] };
    expect(exceedsLevel(jump, 1)).toBe(true);
    expect(exceedsLevel(jump, 2)).toBe(false);
    expect(exceedsLevel(calm, 1)).toBe(false);

    const plan = { days: [{ meals: [], workout: { title: 'Thử', duration_minutes: 20, exercises: [jump, calm] } }] };
    const capped = capWorkoutLevel(plan, 1, []);
    const [first, second] = capped.days[0].workout.exercises;
    expect(first.muscle_group).toBe(MuscleGroup.CARDIO);
    expect(exerciseLevel(first.name)).toBe(1);
    expect(second).toEqual(calm);
  });

  it('never lowers the level into an exercise that loads a declared injury', () => {
    // Cơ lõi mức 1: Dead bug, Gập bụng chạm gót đã có trong buổi → ứng viên còn lại là Bird-dog (quỳ gối, chống tay).
    const exercise = (name: string) => ({ name, sets: 3, reps_or_duration: '30 giây', muscle_group: MuscleGroup.CORE, tags: [] });
    const plan = {
      days: [{ meals: [], workout: { title: 'Cơ lõi', duration_minutes: 20, exercises: ['Plank cẳng tay', 'Dead bug', 'Gập bụng chạm gót'].map(exercise) } }],
    };
    const names = capWorkoutLevel(plan, 1, [ExerciseTag.KNEELING]).days[0].workout.exercises.map((e) => e.name);
    expect(names).toEqual(['Dead bug', 'Gập bụng chạm gót']);
  });

  // Nhờ vậy hạ mức không bao giờ làm rỗng buổi tập, kể cả khi tránh mọi kiểu tải (#25).
  it.each(Object.values(MuscleGroup))('pool has a tag-free level-1 exercise for %s', (group) => {
    expect(exerciseCandidates(group, { avoidTags: Object.values(ExerciseTag), excludeNames: new Set(), maxLevel: 1 })).not.toEqual([]);
  });
});
```

### Task 2 — Tạo plan: thực đơn mẫu và kết quả Gemini

```diff
--- a/backend_api/src/plan/plan.service.ts
+++ b/backend_api/src/plan/plan.service.ts
@@ -5,6 +5,7 @@
 import type { DailyTargetDto, MealPlanResponseDto } from './dto/meal-plan-response.dto.js';
 import type { PlanContentDto } from './dto/plan-content.dto.js';
 import { computeDailyTarget } from './daily-target.js';
+import { capWorkoutLevel, maxExerciseLevel } from './exercise-level.js';
 import { PlanSource } from './enums/plan-source.enum.js';
 import { GeminiService } from './gemini.service.js';
 import { generateWithRetry } from './gemini-retry.js';
@@ -14,6 +15,7 @@
 import { hasRestrictions, profileWarnings, WARNINGS } from './plan-warnings.js';
 import { filterPlanByRestrictions, findRestrictionViolations } from './restriction-filter.js';
 import { matchRestrictions, type RestrictionMatch } from './restriction-matcher.js';
+import type { ExerciseLevel } from './swap-pools.js';
 
 const SAMPLE_PLAN_PATH = fileURLToPath(new URL('./data/sample-plan.json', import.meta.url));
 const SAMPLE_CONTENT = loadSampleContent();
@@ -33,13 +35,15 @@
     const { target, flooredToBmr } = computeDailyTarget(profile);
     const warnings = profileWarnings(profile, flooredToBmr, target.bmr);
     const match = matchRestrictions(profile.restrictions);
+    const maxLevel = maxExerciseLevel(profile);
 
     const content = await this.generateWithGemini(profile, target, match, options.feedbackNote);
     if (content) {
-      return assemblePlan(content, target, PlanSource.GEMINI, warnings);
+      // Prompt đã ghi mức tối đa; động tác Gemini vẫn vượt mức thì thay bằng động tác trong kho, không gọi lại.
+      return assemblePlan(capWorkoutLevel(content, maxLevel, match.avoidTags), target, PlanSource.GEMINI, warnings);
     }
 
-    const sample = buildSampleContent(target, match);
+    const sample = buildSampleContent(target, match, maxLevel);
     if (hasRestrictions(profile)) warnings.push(WARNINGS.sampleKeywordFiltered);
     if (match.hasUnrecognized || sample.incomplete) warnings.push(WARNINGS.restrictionsIncomplete);
     return assemblePlan(sample.plan, target, PlanSource.SAMPLE, warnings);
@@ -73,15 +77,18 @@
   }
 }
 
-// Thực đơn mẫu: lọc theo hạn chế đã nhận ra → nhân khẩu phần từng ngày cho khớp mục tiêu → kiểm đầy đủ.
-// Soạn cho khoảng 1550 kcal/ngày; không nhân lên thì người có mục tiêu cao ăn dưới BMR (BRD NFR-4, v2.5.0).
+// Thực đơn mẫu: lọc theo hạn chế đã nhận ra → hạ mức động tác theo hồ sơ → nhân khẩu phần từng ngày cho khớp
+// mục tiêu → kiểm đầy đủ. Soạn cho khoảng 1550 kcal/ngày; không nhân lên thì người có mục tiêu cao ăn dưới BMR
+// (BRD NFR-4, v2.5.0).
 export function buildSampleContent(
   target: DailyTargetDto,
   match: RestrictionMatch,
+  maxLevel: ExerciseLevel,
 ): { plan: PlanContentDto; incomplete: boolean } {
   const filtered = filterPlanByRestrictions(SAMPLE_CONTENT, match);
+  const capped = capWorkoutLevel(filtered.plan, maxLevel, match.avoidTags);
   const scaled = {
-    days: filtered.plan.days.map((day) => ({ ...day, meals: scaleMealsToTotal(day.meals, target.target_calories) })),
+    days: capped.days.map((day) => ({ ...day, meals: scaleMealsToTotal(day.meals, target.target_calories) })),
   };
   const { plan, errors } = parsePlanContent(scaled, target);
   if (!plan) {
```

```diff
--- a/backend_api/src/plan/plan.service.spec.ts
+++ b/backend_api/src/plan/plan.service.spec.ts
@@ -9,6 +9,7 @@
 import { GeminiTimeoutError, type GeminiService } from './gemini.service.js';
 import { PlanService } from './plan.service.js';
 import { WARNINGS } from './plan-warnings.js';
+import { exerciseLevel } from './swap-pools.js';
 
 const SAMPLE_CONTENT: unknown = JSON.parse(
   readFileSync(fileURLToPath(new URL('./data/sample-plan.json', import.meta.url)), 'utf-8'),
@@ -175,3 +176,32 @@
     expect(generatePlanContent).toHaveBeenCalledWith(expect.anything(), expect.anything(), 'buổi tập rất mệt', 20_000);
   });
 });
+
+describe('PlanService — exercise level and pregnancy (v2.6.0)', () => {
+  afterEach(() => vi.restoreAllMocks());
+
+  const levels = (plan: { days: { workout: { exercises: { name: string }[] } }[] }) =>
+    plan.days.flatMap((day) => day.workout.exercises.map((exercise) => exerciseLevel(exercise.name)));
+  const elderly = () => profile({ age: 65, activity_level: ActivityLevel.SEDENTARY, goal: Goal.MAINTAIN });
+
+  it('gives a 65-year-old sedentary user only level-1 exercises from the sample', async () => {
+    const plan = await new PlanService(geminiOff).generatePlan(elderly());
+    expect(levels(plan).every((level) => level === 1)).toBe(true);
+  });
+
+  it('lowers the level of Gemini exercises without calling Gemini again', async () => {
+    // Thực đơn mẫu dùng làm "đầu ra Gemini" có Jumping Jacks, Squat, Chống đẩy khuỵu gối, Plank (mức 2).
+    // 60 tuổi → mức 1; mục tiêu ~1660 kcal để thực đơn mẫu (~1550 kcal/ngày) vẫn đúng khoảng calo.
+    const { gemini, generatePlanContent } = geminiAnswering(SAMPLE_CONTENT);
+    const plan = await new PlanService(gemini).generatePlan(profile({ age: 60, goal: Goal.MAINTAIN }));
+    expect(plan.source).toBe('gemini');
+    expect(generatePlanContent).toHaveBeenCalledTimes(1);
+    expect(levels(plan).every((level) => level === 1)).toBe(true);
+  });
+
+  it('warns and keeps exercises at level 1 when pregnant or breastfeeding', async () => {
+    const plan = await new PlanService(geminiOff).generatePlan(profile({ goal: Goal.MAINTAIN, pregnant_or_breastfeeding: true }));
+    expect(plan.warnings).toContain(WARNINGS.pregnancy);
+    expect(levels(plan).every((level) => level === 1)).toBe(true);
+  });
+});
```

```diff
--- a/backend_api/src/plan/sample-plan.spec.ts
+++ b/backend_api/src/plan/sample-plan.spec.ts
@@ -6,17 +6,19 @@
 import { Gender } from './enums/gender.enum.js';
 import { Goal } from './enums/goal.enum.js';
 import { PlanSource } from './enums/plan-source.enum.js';
+import { maxExerciseLevel } from './exercise-level.js';
 import { assemblePlan } from './plan-assembly.js';
 import { buildSampleContent } from './plan.service.js';
 import { dayCalorieBounds, parsePlanStructure } from './plan-validation.js';
 import { matchRestrictions } from './restriction-matcher.js';
+import { exerciseLevel } from './swap-pools.js';
 
 const raw: unknown = JSON.parse(
   readFileSync(fileURLToPath(new URL('./data/sample-plan.json', import.meta.url)), 'utf-8'),
 );
 const NO_RESTRICTIONS = matchRestrictions(new RestrictionsDto());
 
-// 18 hồ sơ của ma trận BMR/TDEE + 2 hồ sơ cực trị trong giới hạn BRD 6.1.
+// 18 hồ sơ của ma trận BMR/TDEE + 2 hồ sơ cực trị trong giới hạn BRD 6.1 (tuổi 18–100 từ v2.6.0).
 const PROFILES = [
   ...[Gender.FEMALE, Gender.MALE].flatMap((gender) =>
     Object.values(ActivityLevel).flatMap((activity_level) =>
@@ -29,7 +31,7 @@
     ),
   ),
   { age: 100, gender: Gender.FEMALE, height_cm: 100, weight_kg: 30, activity_level: ActivityLevel.SEDENTARY, goal: Goal.CUT },
-  { age: 10, gender: Gender.MALE, height_cm: 250, weight_kg: 250, activity_level: ActivityLevel.ACTIVE, goal: Goal.BULK },
+  { age: 18, gender: Gender.MALE, height_cm: 250, weight_kg: 250, activity_level: ActivityLevel.ACTIVE, goal: Goal.BULK },
 ];
 
 describe('sample-plan.json', () => {
@@ -57,7 +59,7 @@
   // Trước v2.5.0: thực đơn mẫu cố định ~1550 kcal/ngày, dưới BMR của mọi hồ sơ nam trong ma trận.
   it.each(PROFILES)('is scaled to the target and never below BMR — %o', (profile) => {
     const { target } = computeDailyTarget(profile);
-    const { plan } = buildSampleContent(target, NO_RESTRICTIONS);
+    const { plan } = buildSampleContent(target, NO_RESTRICTIONS, maxExerciseLevel(profile));
     const { min, max } = dayCalorieBounds(target);
     for (const day of plan.days) {
       const total = day.meals.reduce((sum, meal) => sum + meal.calories, 0);
@@ -66,4 +68,14 @@
       expect(Math.abs(total - target.target_calories)).toBeLessThanOrEqual(3);
     }
   });
+
+  // FR-2.2 (v2.6.0): người 100 tuổi ít vận động chỉ nhận động tác mức 1.
+  it.each(PROFILES)('never exceeds the exercise level allowed for the profile — %o', (profile) => {
+    const { target } = computeDailyTarget(profile);
+    const maxLevel = maxExerciseLevel(profile);
+    const { plan } = buildSampleContent(target, NO_RESTRICTIONS, maxLevel);
+    for (const exercise of plan.days.flatMap((day) => day.workout.exercises)) {
+      expect(exerciseLevel(exercise.name) ?? 0).toBeLessThanOrEqual(maxLevel);
+    }
+  });
 });
```

### Task 3 — Prompt

```diff
--- a/backend_api/src/plan/gemini.service.ts
+++ b/backend_api/src/plan/gemini.service.ts
@@ -4,11 +4,13 @@
 import type { CreatePlanDto } from './dto/create-plan.dto.js';
 import type { DailyTargetDto } from './dto/meal-plan-response.dto.js';
 import { ExerciseTag, MuscleGroup } from './enums/exercise.enum.js';
+import { maxExerciseLevel } from './exercise-level.js';
 import { Goal } from './enums/goal.enum.js';
 import { IngredientCategory, IngredientUnit } from './enums/ingredient.enum.js';
 import { MealType } from './enums/meal-type.enum.js';
 import { dayCalorieBounds, MACRO_CALORIE_TOLERANCE, mealCalorieBounds } from './plan-validation.js';
 import { matchRestrictions, type RestrictionMatch } from './restriction-matcher.js';
+import { type ExerciseLevel, SWAP_EXERCISES } from './swap-pools.js';
 import { sanitizeUserText } from './text.util.js';
 
 // Đo với Gemini thật (2026-09-24, `npm run measure:gemini`, gemini-3.5-flash): tạo plan 37–42 s khi model tự suy nghĩ
@@ -160,6 +162,8 @@
     `- Tổng calo mỗi ngày: ${day.min}–${day.max} kcal.`,
     ...mealRules(target.target_calories),
     '- Buổi tập không cần dụng cụ, 15–25 phút.',
+    ...exerciseLevelRule(maxExerciseLevel(profile)),
+    ...pregnancyRule(profile),
     ...exerciseCodeRules(),
     '',
     'Chỉ trả về JSON, không kèm giải thích, đúng cấu trúc:',
@@ -183,6 +187,24 @@
   ];
 }
 
+// Mức động tác tối đa theo hồ sơ (BRD FR-2.2, v2.6.0). Tên động tác lấy từ kho — backend dùng đúng kho này để
+// thay động tác vượt mức (`capWorkoutLevel()`), nên Gemini không phải đoán "nhẹ" là gì.
+export function exerciseLevelRule(maxLevel: ExerciseLevel): string[] {
+  const names = (keep: (level: ExerciseLevel) => boolean) =>
+    SWAP_EXERCISES.filter((exercise) => keep(exercise.level)).map((exercise) => exercise.name).join(', ');
+  if (maxLevel === 1) {
+    return [`- Người dùng chỉ nên tập mức nhẹ nhất: không bật nhảy. Chỉ chọn các động tác như: ${names((level) => level === 1)}.`];
+  }
+  if (maxLevel === 2) return [`- Không dùng động tác nâng cao: ${names((level) => level === 3)}.`];
+  return [];
+}
+
+// Cờ do người dùng bật (không phải chữ tự nhập) nên nằm ngoài khối dữ liệu người dùng.
+export function pregnancyRule(profile: Pick<CreatePlanDto, 'pregnant_or_breastfeeding'>): string[] {
+  if (!profile.pregnant_or_breastfeeding) return [];
+  return ['- Người dùng đang mang thai hoặc cho con bú: món phải nấu chín kỹ, không dùng rượu bia, không ăn kiêng.'];
+}
+
 export const PROMPT_ROLE = 'Bạn là chuyên gia dinh dưỡng và huấn luyện thể lực cho người Việt.';
 
 // Chữ người dùng nhập luôn nằm trong một khối dữ liệu có thẻ phân cách, đã bỏ < > và xuống dòng (NFR-8).
```

```diff
--- a/backend_api/src/plan/adjust/adjust-prompts.ts
+++ b/backend_api/src/plan/adjust/adjust-prompts.ts
@@ -2,11 +2,13 @@
 import type { ExerciseContentDto, MealContentDto } from '../dto/plan-content.dto.js';
 import { Eating } from '../enums/feedback.enum.js';
 import { MealType } from '../enums/meal-type.enum.js';
+import { maxExerciseLevel } from '../exercise-level.js';
 import { matchRestrictions } from '../restriction-matcher.js';
 import {
   EXERCISE_JSON_SHAPE,
   exerciseAvoidRule,
   exerciseCodeRules,
+  exerciseLevelRule,
   ingredientAvoidRule,
   ingredientCodeRules,
   MACRO_RULE,
@@ -66,6 +68,7 @@
     `- Cùng nhóm cơ: muscle_group là ${original.muscle_group}. Bodyweight, không cần dụng cụ.`,
     '- Không chọn động tác gây tải lên vùng chấn thương người dùng đã khai.',
     ...exerciseAvoidRule(matchRestrictions(profile.restrictions)),
+    ...exerciseLevelRule(maxExerciseLevel(profile)),
     `- sets không quá ${original.sets}. tags chỉ được chọn trong: ${tags}.`,
     `- Không trùng các động tác đã có trong buổi: ${avoidNames.join('; ')}.`,
     ...exerciseCodeRules(),
```

```diff
--- a/backend_api/src/plan/gemini-prompt.spec.ts
+++ b/backend_api/src/plan/gemini-prompt.spec.ts
@@ -87,3 +87,34 @@
     expect(buildDayMealsPrompt(restricted, 1624, 2, 1462, { min: 1399, max: 1624 }, Eating.OVER, [])).toContain('Tuyệt đối không dùng');
   });
 });
+
+describe('exercise level and pregnancy rules (v2.6.0)', () => {
+  const withProfile = (overrides: Partial<CreatePlanDto>) => Object.assign(profile({}), overrides);
+
+  it('asks a 65-year-old sedentary user for level-1 exercises only, named from the pool', () => {
+    const prompt = buildPlanPrompt(withProfile({ age: 65, activity_level: ActivityLevel.SEDENTARY, goal: Goal.MAINTAIN }), target);
+    expect(prompt).toContain('chỉ nên tập mức nhẹ nhất');
+    expect(prompt).toContain('Chống đẩy tường');
+    expect(prompt).not.toContain('Jumping Jacks');
+  });
+
+  it('bans the advanced exercises at level 2 and adds no level rule at level 3', () => {
+    expect(buildPlanPrompt(profile({}), target)).toContain('- Không dùng động tác nâng cao:');
+    const active = buildPlanPrompt(withProfile({ activity_level: ActivityLevel.ACTIVE, goal: Goal.MAINTAIN }), target);
+    expect(active).not.toContain('động tác nâng cao');
+    expect(active).not.toContain('mức nhẹ nhất');
+  });
+
+  it('adds the pregnancy rule outside the user data block', () => {
+    const prompt = buildPlanPrompt(withProfile({ goal: Goal.MAINTAIN, pregnant_or_breastfeeding: true }), target);
+    const rule = prompt.indexOf('đang mang thai hoặc cho con bú');
+    expect(rule).toBeGreaterThan(prompt.indexOf('</du_lieu_nguoi_dung>'));
+    expect(buildPlanPrompt(profile({}), target)).not.toContain('mang thai');
+  });
+
+  it('uses the same level rule when asking for a lighter exercise', () => {
+    const exercise = { name: 'Squat tay không', sets: 3, reps_or_duration: '12 lần', muscle_group: MuscleGroup.LEGS, tags: [] };
+    const prompt = buildExerciseSwapPrompt(withProfile({ age: 65, goal: Goal.MAINTAIN }), exercise, ['Squat tay không']);
+    expect(prompt).toContain('chỉ nên tập mức nhẹ nhất');
+  });
+});
```

### Task 4 — Đổi bài và feedback

```diff
--- a/backend_api/src/plan/adjust/exercise-swap.service.ts
+++ b/backend_api/src/plan/adjust/exercise-swap.service.ts
@@ -5,6 +5,7 @@
 import { GeminiService } from '../gemini.service.js';
 import { generateWithRetry } from '../gemini-retry.js';
 import { parseContent } from '../plan-validation.js';
+import { exceedsLevel, maxExerciseLevel } from '../exercise-level.js';
 import { WARNINGS } from '../plan-warnings.js';
 import { hasAvoidedTag } from '../restriction-matcher.js';
 import { exerciseCandidates, exerciseLevel, EXERCISE_LEVELS, toPlanExercise } from '../swap-pools.js';
@@ -32,8 +33,11 @@
     if (!original) throw new BadRequestException(`exercise_id ${dto.exercise_id} không có trong plan`);
 
     const dayNames = new Set(context.plan.days[dayIndex].workout.exercises.map((exercise) => normalizeKey(exercise.name)));
-    // "Nhẹ hơn" đo được bằng code: cùng nhóm cơ, không thêm hiệp, không thêm kiểu tải mới, không vướng chấn thương.
+    const profileMaxLevel = maxExerciseLevel(context.profile);
+    // "Nhẹ hơn" đo được bằng code: cùng nhóm cơ, không thêm hiệp, không thêm kiểu tải mới, không vướng chấn thương,
+    // không vượt mức cho phép của hồ sơ (FR-2.2, v2.6.0).
     const violations = (exercise: ExerciseContentDto): string[] => [
+      ...(exceedsLevel(exercise, profileMaxLevel) ? ['động tác vượt mức khó cho phép của hồ sơ'] : []),
       ...(exercise.muscle_group === original.muscle_group ? [] : [`muscle_group phải là ${original.muscle_group}`]),
       ...(exercise.sets <= original.sets ? [] : [`sets không được quá ${original.sets}`]),
       ...(exercise.tags.every((tag) => original.tags.includes(tag)) ? [] : ['tags thêm kiểu tải mà động tác cũ không có']),
@@ -42,7 +46,7 @@
     ];
 
     const fromGemini = await this.fromGemini(context, original, violations);
-    const replacement = fromGemini ?? this.fromPool(context, original, dayNames, violations);
+    const replacement = fromGemini ?? this.fromPool(context, original, dayNames, violations, profileMaxLevel);
     if (!replacement) {
       throw new UnprocessableEntityException(
         'Không tìm được động tác nhẹ hơn cùng nhóm cơ phù hợp với bạn — động tác này có thể đã là mức nhẹ nhất.',
@@ -86,8 +90,9 @@
     original: ExerciseContentDto,
     dayNames: Set<string>,
     violations: (exercise: ExerciseContentDto) => string[],
+    profileMaxLevel: number,
   ): ExerciseContentDto | null {
-    const maxLevel = (exerciseLevel(original.name) ?? UNKNOWN_LEVEL) - 1;
+    const maxLevel = Math.min((exerciseLevel(original.name) ?? UNKNOWN_LEVEL) - 1, profileMaxLevel);
     const candidates = exerciseCandidates(original.muscle_group, {
       avoidTags: context.match.avoidTags,
       excludeNames: dayNames,
```

```diff
--- a/backend_api/src/plan/adjust/exercise-swap.service.spec.ts
+++ b/backend_api/src/plan/adjust/exercise-swap.service.spec.ts
@@ -1,7 +1,9 @@
 import { UnprocessableEntityException } from '@nestjs/common';
 import { firstPick, geminiAnswering, geminiOff, makeProfile, samplePlan } from '../../../test/plan-fixtures.js';
 import type { MealPlanResponseDto } from '../dto/meal-plan-response.dto.js';
-import { ExerciseTag } from '../enums/exercise.enum.js';
+import { ActivityLevel } from '../enums/activity-level.enum.js';
+import { ExerciseTag, MuscleGroup } from '../enums/exercise.enum.js';
+import { Goal } from '../enums/goal.enum.js';
 import { exerciseLevel } from '../swap-pools.js';
 import { ExerciseSwapService } from './exercise-swap.service.js';
 
@@ -70,3 +72,18 @@
     });
   });
 });
+
+describe('ExerciseSwapService — exercise level of the profile (v2.6.0)', () => {
+  it('rejects a Gemini suggestion above the level allowed for the profile', async () => {
+    const elderly = makeProfile({ age: 65, activity_level: ActivityLevel.SEDENTARY, goal: Goal.MAINTAIN });
+    const elderlyPlan = await samplePlan(elderly);
+    // "Lunge lùi" (mức 2) thoả mọi điều kiện cũ: cùng nhóm cơ, ít hiệp hơn, không thêm tag.
+    const lunge = { name: 'Lunge lùi', sets: 2, reps_or_duration: '10 lần mỗi chân', muscle_group: MuscleGroup.LEGS, tags: [] };
+    const { gemini, generateJson } = geminiAnswering(lunge, lunge);
+
+    await expect(
+      new ExerciseSwapService(gemini, firstPick).swap({ profile: elderly, plan: elderlyPlan, exercise_id: 'e1_2' }),
+    ).rejects.toBeInstanceOf(UnprocessableEntityException);
+    expect(generateJson).toHaveBeenCalledTimes(2);
+  });
+});
```

```diff
--- a/backend_api/src/plan/adjust/workout-rules.ts
+++ b/backend_api/src/plan/adjust/workout-rules.ts
@@ -2,7 +2,7 @@
 import { ExerciseTag, type MuscleGroup } from '../enums/exercise.enum.js';
 import { BodyState, Eating, Intensity } from '../enums/feedback.enum.js';
 import { REST_WORKOUT, STRETCH_EXERCISE, WALK_EXERCISE } from '../exercise-presets.js';
-import { exerciseCandidates, exerciseLevel, toPlanExercise } from '../swap-pools.js';
+import { exerciseCandidates, exerciseLevel, type ExerciseLevel, toPlanExercise } from '../swap-pools.js';
 import { normalizeKey } from '../text.util.js';
 
 // Quy tắc cố định cho buổi tập ngày kế tiếp sau feedback (BRD FR-5.2, D2) — không cần Gemini.
@@ -38,6 +38,7 @@
   feedback: NormalizedFeedback,
   trainedMuscles: Set<MuscleGroup>,
   profileAvoidTags: ExerciseTag[],
+  maxLevel: ExerciseLevel,
 ): WorkoutContentDto {
   if (hasDangerSign(feedback)) return structuredClone(REST_WORKOUT);
 
@@ -45,7 +46,7 @@
   let durationMinutes = workout.duration_minutes;
 
   if (feedback.states.has(BodyState.JOINT_PAIN)) {
-    exercises = replaceJointLoading(exercises, profileAvoidTags);
+    exercises = replaceJointLoading(exercises, profileAvoidTags, maxLevel);
   }
 
   const tired = feedback.intensity === Intensity.HARD || feedback.states.has(BodyState.FATIGUED);
@@ -73,14 +74,18 @@
   return { ...workout, duration_minutes: durationMinutes, exercises };
 }
 
-function replaceJointLoading(exercises: ExerciseContentDto[], profileAvoidTags: ExerciseTag[]): ExerciseContentDto[] {
+function replaceJointLoading(
+  exercises: ExerciseContentDto[],
+  profileAvoidTags: ExerciseTag[],
+  maxLevel: ExerciseLevel,
+): ExerciseContentDto[] {
   const names = new Set(exercises.map((exercise) => normalizeKey(exercise.name)));
   return exercises.flatMap((exercise): ExerciseContentDto[] => {
     if (!exercise.tags.some((tag) => JOINT_PAIN_TAGS.includes(tag))) return [exercise];
     const [candidate] = exerciseCandidates(exercise.muscle_group, {
       avoidTags: [...JOINT_PAIN_TAGS, ...profileAvoidTags],
       excludeNames: names,
-      maxLevel: exerciseLevel(exercise.name) ?? 3,
+      maxLevel: Math.min(exerciseLevel(exercise.name) ?? maxLevel, maxLevel),
     });
     if (!candidate) return [];
     names.add(normalizeKey(candidate.name));
```

```diff
--- a/backend_api/src/plan/adjust/workout-rules.spec.ts
+++ b/backend_api/src/plan/adjust/workout-rules.spec.ts
@@ -2,6 +2,7 @@
 import { ExerciseTag, MuscleGroup } from '../enums/exercise.enum.js';
 import { BodyState, Eating, Intensity } from '../enums/feedback.enum.js';
 import { REST_WORKOUT, STRETCH_EXERCISE, WALK_EXERCISE } from '../exercise-presets.js';
+import { exerciseLevel } from '../swap-pools.js';
 import { adjustWorkout, describeFeedback, normalizeFeedback } from './workout-rules.js';
 
 const workout = (): WorkoutContentDto => ({
@@ -30,7 +31,7 @@
 
 describe('adjustWorkout — danger sign (#14, BRD FR-5.2)', () => {
   it('replaces the whole next workout with rest or a light walk', () => {
-    expect(adjustWorkout(workout(), feedback(Intensity.MODERATE, [BodyState.DANGER_SIGN]), NONE, [])).toEqual(REST_WORKOUT);
+    expect(adjustWorkout(workout(), feedback(Intensity.MODERATE, [BodyState.DANGER_SIGN]), NONE, [], 3)).toEqual(REST_WORKOUT);
   });
 
   it('overrides every other answer, including "easy" and other states', () => {
@@ -39,12 +40,13 @@
       feedback(Intensity.EASY, [BodyState.DANGER_SIGN, BodyState.SORE, BodyState.JOINT_PAIN, BodyState.NORMAL]),
       new Set([MuscleGroup.LEGS]),
       [],
+      3,
     );
     expect(adjusted).toEqual(REST_WORKOUT);
   });
 
   it('returns a copy, so later edits cannot change the preset', () => {
-    const adjusted = adjustWorkout(workout(), feedback(Intensity.HARD, [BodyState.DANGER_SIGN]), NONE, []);
+    const adjusted = adjustWorkout(workout(), feedback(Intensity.HARD, [BodyState.DANGER_SIGN]), NONE, [], 3);
     adjusted.exercises[0].sets = 5;
     expect(REST_WORKOUT.exercises[0].sets).toBe(1);
   });
@@ -52,39 +54,47 @@
 
 describe('adjustWorkout — regular rules (BRD FR-5.2)', () => {
   it('keeps the workout for a moderate session with a normal body', () => {
-    expect(adjustWorkout(workout(), feedback(Intensity.MODERATE, [BodyState.NORMAL]), NONE, [])).toEqual(workout());
+    expect(adjustWorkout(workout(), feedback(Intensity.MODERATE, [BodyState.NORMAL]), NONE, [], 3)).toEqual(workout());
   });
 
   it('adds one set after an easy session, capped at 6', () => {
-    expect(sets(adjustWorkout(workout(), feedback(Intensity.EASY, [BodyState.NORMAL]), NONE, []))).toEqual([3, 4, 4, 6]);
+    expect(sets(adjustWorkout(workout(), feedback(Intensity.EASY, [BodyState.NORMAL]), NONE, [], 3))).toEqual([3, 4, 4, 6]);
   });
 
   it('does not add sets after an easy session when the body is not fine', () => {
-    expect(sets(adjustWorkout(workout(), feedback(Intensity.EASY, [BodyState.FATIGUED]), NONE, []))).toEqual([1, 2, 2, 5]);
+    expect(sets(adjustWorkout(workout(), feedback(Intensity.EASY, [BodyState.FATIGUED]), NONE, [], 3))).toEqual([1, 2, 2, 5]);
   });
 
   it.each([
     ['a hard session', feedback(Intensity.HARD, [BodyState.NORMAL])],
     ['fatigue', feedback(Intensity.MODERATE, [BodyState.FATIGUED])],
   ])('removes one set (at least 1 left) and shortens the session after %s', (_label, input) => {
-    const adjusted = adjustWorkout(workout(), input, NONE, []);
+    const adjusted = adjustWorkout(workout(), input, NONE, [], 3);
     expect(sets(adjusted)).toEqual([1, 2, 2, 5]);
     expect(adjusted.duration_minutes).toBe(15);
   });
 
   it('eases muscle groups trained that day and adds a stretch when sore', () => {
-    const adjusted = adjustWorkout(workout(), feedback(Intensity.MODERATE, [BodyState.SORE]), new Set([MuscleGroup.LEGS]), []);
+    const adjusted = adjustWorkout(workout(), feedback(Intensity.MODERATE, [BodyState.SORE]), new Set([MuscleGroup.LEGS]), [], 3);
     expect(sets(adjusted)).toEqual([2, 2, 3, 6, 1]);
     expect(adjusted.exercises.at(-1)?.name).toBe(STRETCH_EXERCISE.name);
   });
 
   it('does not stack the sore reduction on top of the tired one', () => {
-    const adjusted = adjustWorkout(workout(), feedback(Intensity.HARD, [BodyState.SORE]), new Set([MuscleGroup.LEGS]), []);
+    const adjusted = adjustWorkout(workout(), feedback(Intensity.HARD, [BodyState.SORE]), new Set([MuscleGroup.LEGS]), [], 3);
     expect(sets(adjusted)).toEqual([1, 2, 2, 5, 1]);
   });
 
+  it('replaces joint-loading exercises only with exercises inside the allowed level (v2.6.0)', () => {
+    const before = new Set(workout().exercises.map((exercise) => exercise.name));
+    const adjusted = adjustWorkout(workout(), feedback(Intensity.MODERATE, [BodyState.JOINT_PAIN]), NONE, [], 1);
+    const added = adjusted.exercises.filter((exercise) => !before.has(exercise.name));
+    expect(added.length).toBeGreaterThan(0);
+    for (const exercise of added) expect(exerciseLevel(exercise.name)).toBe(1);
+  });
+
   it('replaces jumping and kneeling exercises on joint pain, respecting declared injuries', () => {
-    const adjusted = adjustWorkout(workout(), feedback(Intensity.MODERATE, [BodyState.JOINT_PAIN]), NONE, [ExerciseTag.WRIST_LOAD]);
+    const adjusted = adjustWorkout(workout(), feedback(Intensity.MODERATE, [BodyState.JOINT_PAIN]), NONE, [ExerciseTag.WRIST_LOAD], 3);
     const tags = adjusted.exercises.flatMap((exercise) => exercise.tags);
     expect(tags).not.toContain(ExerciseTag.JUMPING);
     expect(tags).not.toContain(ExerciseTag.KNEELING);
@@ -99,10 +109,10 @@
 
   it('falls back to a walk when nothing is left', () => {
     const only: WorkoutContentDto = { ...workout(), exercises: [{ ...workout().exercises[0], name: 'Bật nhảy lạ', muscle_group: MuscleGroup.SHOULDERS, tags: [ExerciseTag.JUMPING] }] };
-    const adjusted = adjustWorkout(only, feedback(Intensity.MODERATE, [BodyState.JOINT_PAIN]), NONE, [ExerciseTag.OVERHEAD, ExerciseTag.WRIST_LOAD]);
+    const adjusted = adjustWorkout(only, feedback(Intensity.MODERATE, [BodyState.JOINT_PAIN]), NONE, [ExerciseTag.OVERHEAD, ExerciseTag.WRIST_LOAD], 3);
     expect(adjusted.exercises.length).toBeGreaterThan(0);
     expect(adjusted.exercises.every((exercise) => !exercise.tags.includes(ExerciseTag.JUMPING))).toBe(true);
-    const empty = adjustWorkout({ ...workout(), exercises: [] }, feedback(Intensity.MODERATE, [BodyState.NORMAL]), NONE, []);
+    const empty = adjustWorkout({ ...workout(), exercises: [] }, feedback(Intensity.MODERATE, [BodyState.NORMAL]), NONE, [], 3);
     expect(empty.exercises).toEqual([WALK_EXERCISE]);
   });
 
@@ -111,7 +121,7 @@
       ...workout(),
       exercises: Array.from({ length: 8 }, (_, i) => ({ ...workout().exercises[1], name: `Động tác ${i}` })),
     };
-    expect(adjustWorkout(full, feedback(Intensity.MODERATE, [BodyState.SORE]), NONE, []).exercises).toHaveLength(8);
+    expect(adjustWorkout(full, feedback(Intensity.MODERATE, [BodyState.SORE]), NONE, [], 3).exercises).toHaveLength(8);
   });
 });
```

```diff
--- a/backend_api/src/plan/adjust/feedback.service.ts
+++ b/backend_api/src/plan/adjust/feedback.service.ts
@@ -14,6 +14,7 @@
 import { PlanService } from '../plan.service.js';
 import { SAFETY_WARNING_MESSAGE, WARNINGS } from '../plan-warnings.js';
 import { findRestrictionViolations } from '../restriction-filter.js';
+import { maxExerciseLevel } from '../exercise-level.js';
 import { matchRestrictions } from '../restriction-matcher.js';
 import { buildDayMealsPrompt } from './adjust-prompts.js';
 import { type ClientPlanContext, readClientPlan, rebuildPlan } from './client-plan.js';
@@ -63,7 +64,7 @@
     const days: DayContentDto[] = context.plan.days.map((day) => ({ meals: day.meals, workout: day.workout }));
     days[nextIndex] = {
       ...days[nextIndex],
-      workout: adjustWorkout(days[nextIndex].workout, feedback, trainedMuscles, context.match.avoidTags),
+      workout: adjustWorkout(days[nextIndex].workout, feedback, trainedMuscles, context.match.avoidTags, maxExerciseLevel(context.profile)),
     };
 
     const extra: string[] = [];
@@ -86,7 +87,7 @@
     const avoidTags = matchRestrictions(context.profile.restrictions).avoidTags;
     const days: DayContentDto[] = next.days.map((day, index) => ({
       meals: day.meals,
-      workout: index === 0 ? adjustWorkout(day.workout, feedback, trainedMuscles, avoidTags) : day.workout,
+      workout: index === 0 ? adjustWorkout(day.workout, feedback, trainedMuscles, avoidTags, maxExerciseLevel(context.profile)) : day.workout,
     }));
     const warnings = [...next.warnings];
     if (next.source === PlanSource.SAMPLE && feedback.eating !== Eating.ON_PLAN && !hasDangerSign(feedback)) {
```

### Task 5 — `ai_workspace`

```diff
--- a/ai_workspace/generate-plan-experiment.ts
+++ b/ai_workspace/generate-plan-experiment.ts
@@ -60,6 +60,8 @@
     '- ingredients[].category chỉ được là: protein (thịt, cá, trứng, đậu phụ, sữa), produce (rau, củ, quả), pantry (gạo, bún, mì, gia vị, dầu ăn).',
     '- ingredients[].unit chỉ được là: g, ml, piece, tbsp, tsp.',
     '- Buổi tập không cần dụng cụ, 15–25 phút.',
+    // Backend dựng dòng dưới bằng exerciseLevelRule() từ kho động tác: hồ sơ này (22 tuổi, vận động nhẹ) được tối đa mức 2.
+    '- Không dùng động tác nâng cao: Squat nhảy, Bulgarian split squat (chân sau gác ghế), Chống đẩy tiêu chuẩn, Superman giữ tư thế, Leo núi (Mountain climber), Pike push-up, Chống đẩy kim cương, Burpee, Nhảy dây không dây.',
     '- exercises[].muscle_group chỉ được là: legs, chest, back, core, shoulders, arms, full_body, cardio.',
     '- exercises[].tags chọn trong: jumping, kneeling, wrist_load, back_load, overhead (để mảng rỗng nếu không có).',
     '',
```

Kiểm prompt hai bên trùng nhau (sau `npm run build`):

```bash
cd ai_workspace
python3 -c "s=open('generate-plan-experiment.ts').read(); i=s.index('\nmain().catch('); open('/tmp/prompt_dump.ts','w').write(s[:i]+'\nconsole.log(buildPrompt());\n')"
cp /tmp/prompt_dump.ts ./prompt_dump.ts && GEMINI_API_KEY=x npx tsx prompt_dump.ts > /tmp/ai_prompt.txt; rm prompt_dump.ts
cd ../backend_api && node --input-type=module -e "
const m = await import('./dist/plan/gemini.service.js');
const { CreatePlanDto } = await import('./dist/plan/dto/create-plan.dto.js');
const { RestrictionsDto } = await import('./dist/plan/dto/restrictions.dto.js');
const p = Object.assign(new CreatePlanDto(), { age: 22, gender: 'female', height_cm: 168, weight_kg: 62, activity_level: 'light', goal: 'cut', restrictions: Object.assign(new RestrictionsDto(), { allergies: 'Hải sản', injuries: 'Đau gối' }) });
console.log(m.buildPlanPrompt(p, { bmi: 22, bmr: 1399, tdee: 1924, target_calories: 1624, protein_g: 102, carbs_g: 183, fat_g: 54 }));" > /tmp/be_prompt.txt
diff /tmp/be_prompt.txt /tmp/ai_prompt.txt && echo "PROMPT GIỐNG HỆT"
```

### Task 6 — Cổng kiểm tra F02

```bash
cd backend_api && npm run typecheck && npm run build
npm test            # Tests  320 passed (320)
npm run test:e2e    # Tests  74 passed (74) — fixture không đổi
npm run test:smoke && npm run lint
cd ../ai_workspace && npx tsc --noEmit
```
