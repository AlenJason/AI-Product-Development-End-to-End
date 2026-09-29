# F02 — Nhận plan từ client, DTO của mục 6.4, cập nhật lịch sử

## Feature

Phần dùng chung của ba endpoint đổi món, đổi bài tập, feedback. Backend không lưu trạng thái: client gửi `{ profile, plan, … }`, nhận lại cả plan mới (BRD 6.4).

- **DTO** `AdjustPlanDto` / `SwapMealDto` / `SwapExerciseDto` / `FeedbackDto`, response `PlanEnvelopeDto` / `FeedbackResponseDto`, enum `Intensity` / `BodyState` / `Eating`. `profile` và `plan` có `@IsDefined()`: thiếu hẳn trường thì `@ValidateNested()` bỏ qua không kiểm, service nhận `undefined` và trả **500**. E2E ở F06 phát hiện lỗi này khi lập plan.
- **`readClientPlan()`** kiểm plan client gửi lên:
  - tính lại mục tiêu calo từ `profile` (#13); `daily_target` của plan khác mục tiêu vừa tính → **409** "Kế hoạch này được tạo cho hồ sơ khác" (brainstorm F7);
  - `day_number`, thứ tự bữa, `meal_id`, `exercise_id` phải đúng vị trí (#16);
  - `findPlanViolations()` (#2). Sai → **400**.
- **`rebuildPlan()`**: lắp lại plan sau khi sửa. Giữ `plan_id` và `source`; ID gán lại theo vị trí; danh sách đi chợ tính lại (#7); `warnings` tính lại từ hồ sơ hiện tại, không lấy `warnings` client gửi.
- **`HistoryService.update()`** (quyết định Q4): cập nhật `plan_json` của plan đã lưu nếu `plan_id` thuộc người đang đăng nhập. Plan của người khác, hoặc plan tạo lúc chưa đăng nhập → không có dòng nào khớp, bỏ qua. Chỉ trả `false` khi DB lỗi.
- `RandomSource`: nguồn ngẫu nhiên khi chọn trong kho (F03, F04), thay được bằng giá trị cố định khi test.
- `test/plan-fixtures.ts`: hồ sơ mẫu, plan mẫu do chính server tạo, Gemini giả cho `generateJson()`.

## Scope

API:

- `backend_api/src/plan/enums/feedback.enum.ts` (mới)
- `backend_api/src/plan/dto/adjust-plan.dto.ts` (mới)
- `backend_api/src/plan/adjust/client-plan.ts` + `client-plan.spec.ts` (mới)
- `backend_api/src/plan/adjust/random-source.ts` (mới)
- `backend_api/src/history/history.service.ts` + `history.service.spec.ts` (sửa)
- `backend_api/test/plan-fixtures.ts` (mới)

## Implementation

### API Routes

Chưa thêm route (F06 nối controller). Lỗi mà ba endpoint sẽ trả từ phần này: **400** (request hoặc plan sai hợp đồng, ID sai vị trí), **409** (plan tạo cho hồ sơ khác). `readClientPlan()` là tính toán thuần, không gọi mạng, dưới 1 ms.

### UI Components

Không có. App (giai đoạn 7) cần xử lý 409: gợi ý tạo plan mới.

### DB / KV Changes

Không đổi schema. `update()` dùng `Repository.update({ id, user_id }, { plan_json, target_calories })`. Khi lập plan đã kiểm với SQLite trong RAM rằng cột `simple-json` được ghi đúng. `created_at` giữ nguyên, nên thứ tự lịch sử vẫn theo lúc tạo.

### Ràng buộc áp dụng

- **#2** plan client gửi lên qua `findPlanViolations()`.
- **#7** danh sách đi chợ tính lại trong `rebuildPlan()`.
- **#12** thông báo 400 chỉ nêu vị trí, tên món và số calo lấy từ chính plan; không có chữ người dùng nhập.
- **#13** mục tiêu calo và BMR tính lại từ `profile`, không tin số trong plan.
- **#16** ID phải đúng vị trí; lắp lại thì gán lại ID.
- **#22** cập nhật lịch sử không bao giờ đụng plan của người khác.

## Definition of Done

- [ ] `npm test` → `Test Files  20 passed (20)`, `Tests  196 passed (196)`
- [ ] `npm run test:e2e` → `Tests  37 passed (37)`
- [ ] `client-plan.spec.ts`: 10 test (plan hợp lệ; 409 hai kiểu; 400 sáu kiểu; `rebuildPlan` giữ `plan_id`, tính lại đi chợ và cảnh báo)
- [ ] `history.service.spec.ts`: 9 test (thêm 3: cập nhật đúng chủ, bỏ qua plan chưa lưu, DB lỗi → false)
- [x] All API routes complete within deployment timeout — chưa có route
- [x] Auth check at top of each protected handler — chưa có route

## Test Checklist

1. **@happy**: plan server vừa trả, gửi lại nguyên vẹn → qua; `rebuildPlan` giữ `plan_id`
2. **@auth**: `update()` với người khác → plan của chủ không đổi
3. **@timeout**: không áp dụng
4. **@partial-fail**: DB lỗi khi cập nhật → `false`, không ném lỗi
5. **@token**: không áp dụng
6. **@db**: cập nhật đúng dòng, `plan_json` đọc lại khớp; plan chưa lưu → không thêm dòng

## Tasks

### Task 1 — Enum và DTO

`backend_api/src/plan/enums/feedback.enum.ts`:

```ts
// Câu trả lời của bảng feedback cuối ngày (BRD FR-5.1, mục 6.4).

export enum Intensity {
  EASY = 'easy',
  MODERATE = 'moderate',
  HARD = 'hard',
}

export enum BodyState {
  NORMAL = 'normal',
  SORE = 'sore',
  JOINT_PAIN = 'joint_pain',
  FATIGUED = 'fatigued',
  DANGER_SIGN = 'danger_sign',
}

export enum Eating {
  ON_PLAN = 'on_plan',
  OVER = 'over',
  UNDER = 'under',
}
```

`backend_api/src/plan/dto/adjust-plan.dto.ts`:

```ts
import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { ArrayMaxSize, ArrayMinSize, IsArray, IsDefined, IsEnum, IsInt, Matches, Max, Min, ValidateNested } from 'class-validator';
import { BodyState, Eating, Intensity } from '../enums/feedback.enum.js';
import { CreatePlanDto } from './create-plan.dto.js';
import { MealPlanResponseDto } from './meal-plan-response.dto.js';

// Request/response của đổi món, đổi bài tập, feedback (BRD mục 6.4). Backend không lưu trạng thái:
// client gửi cả hồ sơ lẫn plan hiện tại, nhận lại cả plan mới.

// @IsDefined: thiếu hẳn trường thì @ValidateNested bỏ qua không kiểm, service nhận undefined và trả 500.
export class AdjustPlanDto {
  @ApiProperty({ type: CreatePlanDto, description: 'Hồ sơ hiện tại, cùng cấu trúc request 6.1' })
  @IsDefined()
  @ValidateNested()
  @Type(() => CreatePlanDto)
  profile: CreatePlanDto;

  @ApiProperty({ type: MealPlanResponseDto, description: 'Plan đang dùng, đúng như server đã trả' })
  @IsDefined()
  @ValidateNested()
  @Type(() => MealPlanResponseDto)
  plan: MealPlanResponseDto;
}

export class SwapMealDto extends AdjustPlanDto {
  @ApiProperty({ example: 'm1_2' })
  @Matches(/^m[1-3]_[1-3]$/, { message: 'meal_id phải có dạng m{ngày}_{bữa}, ví dụ m1_2' })
  meal_id: string;
}

export class SwapExerciseDto extends AdjustPlanDto {
  @ApiProperty({ example: 'e1_3' })
  @Matches(/^e[1-3]_[1-8]$/, { message: 'exercise_id phải có dạng e{ngày}_{thứ tự}, ví dụ e1_3' })
  exercise_id: string;
}

export class FeedbackDto extends AdjustPlanDto {
  @ApiProperty({ example: 1, description: '1–2: điều chỉnh ngày kế tiếp; 3: tạo plan 3 ngày mới (FR-5.3)' })
  @IsInt()
  @Min(1)
  @Max(3)
  day_number: number;

  @ApiProperty({ enum: Intensity, example: Intensity.HARD })
  @IsEnum(Intensity)
  intensity: Intensity;

  @ApiProperty({ enum: BodyState, isArray: true, example: [BodyState.SORE] })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(5)
  @IsEnum(BodyState, { each: true })
  body_states: BodyState[];

  @ApiProperty({ enum: Eating, example: Eating.OVER })
  @IsEnum(Eating)
  eating: Eating;
}

export class PlanEnvelopeDto {
  @ApiProperty({ type: MealPlanResponseDto })
  plan: MealPlanResponseDto;
}

export class SafetyWarningDto {
  @ApiProperty({ example: 'Hãy ngừng tập và hỏi ý kiến bác sĩ…' })
  message: string;
}

export class FeedbackResponseDto extends PlanEnvelopeDto {
  @ApiProperty({ type: SafetyWarningDto, nullable: true, description: 'Khác null khi có dấu hiệu nguy hiểm' })
  safety_warning: SafetyWarningDto | null;
}
```

### Task 2 — Fixture dùng chung và nguồn ngẫu nhiên

`backend_api/src/plan/adjust/random-source.ts`:

```ts
import { Injectable } from '@nestjs/common';

// Nguồn ngẫu nhiên khi chọn món/động tác thay thế trong kho, để đổi nhiều lần không lặp đi lặp lại một cặp món.
// Test thay bằng giá trị cố định để kết quả lặp lại được.
@Injectable()
export class RandomSource {
  next(): number {
    return Math.random();
  }
}

export function pickOne<T>(items: T[], random: RandomSource): T | undefined {
  if (items.length === 0) return undefined;
  return items[Math.min(items.length - 1, Math.floor(random.next() * items.length))];
}
```

`backend_api/test/plan-fixtures.ts`:

```ts
import { CreatePlanDto } from '../src/plan/dto/create-plan.dto.js';
import type { MealPlanResponseDto } from '../src/plan/dto/meal-plan-response.dto.js';
import { RestrictionsDto } from '../src/plan/dto/restrictions.dto.js';
import { ActivityLevel } from '../src/plan/enums/activity-level.enum.js';
import { Gender } from '../src/plan/enums/gender.enum.js';
import { Goal } from '../src/plan/enums/goal.enum.js';
import type { GeminiService } from '../src/plan/gemini.service.js';
import { PlanService } from '../src/plan/plan.service.js';
import { RandomSource } from '../src/plan/adjust/random-source.js';

// Dữ liệu dùng chung cho test đổi món, đổi bài tập, feedback (giai đoạn 4).

export function makeProfile(
  overrides: Partial<Omit<CreatePlanDto, 'restrictions'>> = {},
  restrictions: Partial<RestrictionsDto> = {},
): CreatePlanDto {
  return Object.assign(new CreatePlanDto(), {
    age: 22,
    gender: Gender.FEMALE,
    height_cm: 168,
    weight_kg: 62,
    activity_level: ActivityLevel.LIGHT,
    goal: Goal.CUT,
    ...overrides,
    restrictions: Object.assign(new RestrictionsDto(), restrictions),
  });
}

export const geminiOff = { isConfigured: false } as unknown as GeminiService;

// Gemini giả cho generateJson(): mỗi phần tử là kết quả của một lần gọi — Error thì ném ra, còn lại thì trả về.
export function geminiAnswering(...answers: unknown[]) {
  const generateJson = vi.fn();
  for (const answer of answers) {
    if (answer instanceof Error) generateJson.mockRejectedValueOnce(answer);
    else generateJson.mockResolvedValueOnce(answer);
  }
  return { gemini: { isConfigured: true, generateJson } as unknown as GeminiService, generateJson };
}

// Plan hợp lệ do chính server tạo (thực đơn mẫu, không Gemini) — giống plan app sẽ gửi lại.
export function samplePlan(profile: CreatePlanDto = makeProfile()): Promise<MealPlanResponseDto> {
  return new PlanService(geminiOff).generatePlan(profile);
}

// Luôn chọn ứng viên đầu tiên (hoặc cuối cùng) để test lặp lại được.
export const firstPick = { next: () => 0 } as RandomSource;
export const lastPick = { next: () => 0.999 } as RandomSource;
```

### Task 3 — `readClientPlan()` / `rebuildPlan()`: test trước

`backend_api/src/plan/adjust/client-plan.spec.ts`:

```ts
import { BadRequestException, ConflictException } from '@nestjs/common';
import { makeProfile, samplePlan } from '../../../test/plan-fixtures.js';
import type { MealPlanResponseDto } from '../dto/meal-plan-response.dto.js';
import { Goal } from '../enums/goal.enum.js';
import { WARNINGS } from '../plan-warnings.js';
import { readClientPlan, rebuildPlan } from './client-plan.js';

describe('readClientPlan', () => {
  let plan: MealPlanResponseDto;

  beforeAll(async () => {
    plan = await samplePlan();
  });

  it('accepts a plan exactly as the server returned it', () => {
    const context = readClientPlan(makeProfile(), plan);
    expect(context.target.target_calories).toBe(1624);
  });

  it('answers 409 when the profile no longer matches the plan target (#13)', () => {
    expect(() => readClientPlan(makeProfile({ goal: Goal.BULK }), plan)).toThrow(ConflictException);
  });

  it('never trusts the bmr sent by the client', () => {
    const forged = structuredClone(plan);
    forged.daily_target.bmr = 900;
    expect(() => readClientPlan(makeProfile(), forged)).toThrow(ConflictException);
  });

  it.each<[string, (p: MealPlanResponseDto) => void]>([
    ['meal ids out of position', (p) => ([p.days[0].meals[0].meal_id, p.days[0].meals[1].meal_id] = ['m1_2', 'm1_1'])],
    ['meals out of order', (p) => p.days[1].meals.reverse()],
    ['a wrong exercise id', (p) => (p.days[2].workout.exercises[0].exercise_id = 'e1_1')],
    ['a wrong day number', (p) => (p.days[1].day_number = 3)],
    ['impossible calories', (p) => (p.days[0].meals[0].calories = 5000)],
    ['a repeated dish', (p) => (p.days[2].meals[2].name = p.days[0].meals[2].name)],
  ])('answers 400 to %s (#2, #16)', (_label, tamper) => {
    const tampered = structuredClone(plan);
    tamper(tampered);
    expect(() => readClientPlan(makeProfile(), tampered)).toThrow(BadRequestException);
  });
});

describe('rebuildPlan', () => {
  it('keeps plan_id and source, recomputes grocery list and warnings from the profile', async () => {
    const plan = await samplePlan();
    const forged = { ...structuredClone(plan), warnings: ['cảnh báo giả'], grocery_list: [] };
    const profile = makeProfile({}, { allergies: 'hải sản', health_conditions: 'tiểu đường' });
    const rebuilt = rebuildPlan(readClientPlan(profile, forged), forged.days);

    expect(rebuilt.plan_id).toBe(plan.plan_id);
    expect(rebuilt.source).toBe('sample');
    expect(rebuilt.grocery_list).toEqual(plan.grocery_list);
    expect(rebuilt.warnings).toEqual([WARNINGS.healthConditions, WARNINGS.sampleKeywordFiltered]);
  });
});
```

```bash
cd backend_api
npx vitest run src/plan/adjust/client-plan.spec.ts   # đỏ: Cannot find module './client-plan.js'
```

`backend_api/src/plan/adjust/client-plan.ts`:

```ts
import { BadRequestException, ConflictException } from '@nestjs/common';
import { computeDailyTarget } from '../daily-target.js';
import type { CreatePlanDto } from '../dto/create-plan.dto.js';
import type { DailyTargetDto, MealPlanResponseDto } from '../dto/meal-plan-response.dto.js';
import type { DayContentDto } from '../dto/plan-content.dto.js';
import { PlanSource } from '../enums/plan-source.enum.js';
import { assemblePlan, MEAL_ORDER } from '../plan-assembly.js';
import { findPlanViolations } from '../plan-validation.js';
import { hasRestrictions, profileWarnings, WARNINGS } from '../plan-warnings.js';
import { matchRestrictions, type RestrictionMatch } from '../restriction-matcher.js';

export interface ClientPlanContext {
  profile: CreatePlanDto;
  plan: MealPlanResponseDto;
  target: DailyTargetDto;
  flooredToBmr: boolean;
  match: RestrictionMatch;
}

// Kiểm plan client gửi lên trước khi đổi món/đổi bài/feedback (BRD 6.4, #2, #13, #16).
// Cấu trúc đã qua ValidationPipe; ở đây kiểm ID đúng vị trí, quy tắc calo/trùng món, và mục tiêu calo
// tính lại từ hồ sơ — không tin `daily_target`, `grocery_list`, `warnings` trong plan.
export function readClientPlan(profile: CreatePlanDto, plan: MealPlanResponseDto): ClientPlanContext {
  const { target, flooredToBmr } = computeDailyTarget(profile);
  if (plan.daily_target.target_calories !== target.target_calories || plan.daily_target.bmr !== target.bmr) {
    throw new ConflictException('Kế hoạch này được tạo cho hồ sơ khác (mục tiêu calo đã đổi). Hãy tạo kế hoạch mới.');
  }
  const violations = [...findIdErrors(plan), ...findPlanViolations(plan, target)];
  if (violations.length > 0) {
    throw new BadRequestException(['Kế hoạch gửi lên không đúng hợp đồng', ...violations.slice(0, 10)]);
  }
  return { profile, plan, target, flooredToBmr, match: matchRestrictions(profile.restrictions) };
}

// Lắp lại plan sau khi sửa: giữ plan_id và source, gán lại ID theo vị trí, tính lại danh sách đi chợ (#7)
// và cảnh báo từ hồ sơ hiện tại.
export function rebuildPlan(
  context: ClientPlanContext,
  days: DayContentDto[],
  extraWarnings: string[] = [],
): MealPlanResponseDto {
  return assemblePlan(
    { days },
    context.target,
    context.plan.source,
    unique([...planWarnings(context), ...extraWarnings]),
    context.plan.plan_id,
  );
}

// Cảnh báo theo hồ sơ + theo nguồn plan: plan mẫu chỉ được lọc bằng từ khoá (D4).
export function planWarnings(context: Pick<ClientPlanContext, 'profile' | 'plan' | 'target' | 'flooredToBmr' | 'match'>): string[] {
  const warnings = profileWarnings(context.profile, context.flooredToBmr, context.target.bmr);
  if (context.plan.source === PlanSource.SAMPLE && hasRestrictions(context.profile)) {
    warnings.push(WARNINGS.sampleKeywordFiltered);
    if (context.match.hasUnrecognized) warnings.push(WARNINGS.restrictionsIncomplete);
  }
  return warnings;
}

function findIdErrors(plan: MealPlanResponseDto): string[] {
  const errors: string[] = [];
  plan.days.forEach((day, dayIndex) => {
    const dayNumber = dayIndex + 1;
    if (day.day_number !== dayNumber) errors.push(`days[${dayIndex}].day_number phải là ${dayNumber}`);
    day.meals.forEach((meal, mealIndex) => {
      if (meal.meal_type !== MEAL_ORDER[mealIndex] || meal.meal_id !== `m${dayNumber}_${mealIndex + 1}`) {
        errors.push(`Ngày ${dayNumber}: bữa thứ ${mealIndex + 1} phải là ${MEAL_ORDER[mealIndex]} với meal_id m${dayNumber}_${mealIndex + 1}`);
      }
    });
    day.workout.exercises.forEach((exercise, exerciseIndex) => {
      if (exercise.exercise_id !== `e${dayNumber}_${exerciseIndex + 1}`) {
        errors.push(`Ngày ${dayNumber}: động tác thứ ${exerciseIndex + 1} phải có exercise_id e${dayNumber}_${exerciseIndex + 1}`);
      }
    });
  });
  return errors;
}

function unique(values: string[]): string[] {
  return [...new Set(values)];
}
```

```bash
npx vitest run src/plan/adjust/client-plan.spec.ts   # Tests  10 passed (10)
```

### Task 4 — `HistoryService.update()`: test trước

Bản đầy đủ của test (thêm 3 test trước test "answers an unknown id with 404"):

`backend_api/src/history/history.service.spec.ts`:

```ts
import { Logger, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import type { DataSource, Repository } from 'typeorm';
import { createMemoryDataSource } from '../../test/memory-data-source.js';
import { PlanRecord } from '../database/entities/plan-record.entity.js';
import { User } from '../database/entities/user.entity.js';
import type { MealPlanResponseDto } from '../plan/dto/meal-plan-response.dto.js';
import { HISTORY_LIMIT, HistoryService } from './history.service.js';

const fakePlan = (targetCalories = 1800): MealPlanResponseDto =>
  ({ plan_id: randomUUID(), daily_target: { target_calories: targetCalories }, days: [] }) as unknown as MealPlanResponseDto;

describe('HistoryService', () => {
  let dataSource: DataSource;
  let plans: Repository<PlanRecord>;
  let service: HistoryService;
  let an: User;
  let binh: User;

  beforeEach(async () => {
    dataSource = await createMemoryDataSource();
    plans = dataSource.getRepository(PlanRecord);
    service = new HistoryService(plans);
    const users = dataSource.getRepository(User);
    an = await users.save(users.create({ google_sub: 'mock:an@vku.edu.vn', email: 'an@vku.edu.vn', name: 'an' }));
    binh = await users.save(users.create({ google_sub: 'mock:binh@vku.edu.vn', email: 'binh@vku.edu.vn', name: 'binh' }));
  });

  afterEach(async () => {
    vi.restoreAllMocks();
    await dataSource.destroy();
  });

  it('saves a plan and returns it unchanged', async () => {
    const plan = fakePlan(1624);
    expect(await service.save(an.id, plan)).toBe(true);
    await expect(service.findOne(an.id, plan.plan_id)).resolves.toEqual(plan);
    expect(await service.list(an.id)).toEqual({
      plans: [{ id: plan.plan_id, created_at: expect.stringMatching(/^\d{4}-\d{2}-\d{2}T.*Z$/), target_calories: 1624 }],
    });
  });

  it('returns false instead of throwing when the database refuses the plan', async () => {
    const error = vi.spyOn(Logger.prototype, 'error').mockImplementation(() => undefined);
    expect(await service.save(randomUUID(), fakePlan())).toBe(false); // user không tồn tại → vi phạm khoá ngoại
    expect(error).toHaveBeenCalledTimes(1);
    expect(await plans.count()).toBe(0);
  });

  it(`lists at most ${HISTORY_LIMIT} plans, newest first`, async () => {
    const base = Date.parse('2026-09-01T00:00:00.000Z');
    await plans.insert(
      Array.from({ length: HISTORY_LIMIT + 5 }, (_, index) => ({
        id: randomUUID(),
        user_id: an.id,
        target_calories: 1500 + index,
        plan_json: fakePlan(),
        created_at: new Date(base + index * 1000),
      })),
    );
    const { plans: listed } = await service.list(an.id);
    expect(listed).toHaveLength(HISTORY_LIMIT);
    expect(listed[0]).toMatchObject({ target_calories: 1500 + HISTORY_LIMIT + 4, created_at: new Date(base + (HISTORY_LIMIT + 4) * 1000).toISOString() });
    expect(listed.at(-1)?.target_calories).toBe(1505);
  });

  it('keeps plans saved within the same second in creation order', async () => {
    const first = fakePlan(1500);
    const second = fakePlan(1600);
    await service.save(an.id, first);
    await new Promise((resolve) => setTimeout(resolve, 5));
    await service.save(an.id, second);
    expect((await service.list(an.id)).plans.map((plan) => plan.id)).toEqual([second.plan_id, first.plan_id]);
  });

  it("never shows one user's plans to another", async () => {
    const plan = fakePlan();
    await service.save(an.id, plan);
    expect(await service.list(binh.id)).toEqual({ plans: [] });
    await expect(service.findOne(binh.id, plan.plan_id)).rejects.toBeInstanceOf(NotFoundException);
  });

  it("updates a saved plan in place, but never another user's", async () => {
    const plan = fakePlan(1624);
    await service.save(an.id, plan);
    const edited = { ...plan, warnings: ['đã đổi món'] } as MealPlanResponseDto;

    expect(await service.update(binh.id, edited)).toBe(true);
    await expect(service.findOne(an.id, plan.plan_id)).resolves.toEqual(plan);

    expect(await service.update(an.id, edited)).toBe(true);
    await expect(service.findOne(an.id, plan.plan_id)).resolves.toEqual(edited);
    expect(await plans.count()).toBe(1);
  });

  it('ignores an update for a plan that was never saved', async () => {
    expect(await service.update(an.id, fakePlan())).toBe(true);
    expect(await plans.count()).toBe(0);
  });

  it('returns false instead of throwing when the update fails', async () => {
    vi.spyOn(Logger.prototype, 'error').mockImplementation(() => undefined);
    await dataSource.query('DROP TABLE plan_records');
    expect(await service.update(an.id, fakePlan())).toBe(false);
  });

  it('answers an unknown id with 404', async () => {
    await expect(service.findOne(an.id, randomUUID())).rejects.toBeInstanceOf(NotFoundException);
  });
});
```

```bash
npx vitest run src/history/history.service.spec.ts   # đỏ: service.update is not a function
```

`backend_api/src/history/history.service.ts`:

```ts
import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import type { Repository } from 'typeorm';
import { PlanRecord } from '../database/entities/plan-record.entity.js';
import type { MealPlanResponseDto } from '../plan/dto/meal-plan-response.dto.js';
import type { PlanHistoryResponseDto } from './dto/plan-history-response.dto.js';

export const HISTORY_LIMIT = 50;

@Injectable()
export class HistoryService {
  private readonly logger = new Logger(HistoryService.name);

  constructor(@InjectRepository(PlanRecord) private readonly plans: Repository<PlanRecord>) {}

  // Trả false thay vì ném lỗi: lịch sử lỗi không được làm mất plan vừa tạo xong.
  async save(userId: string, plan: MealPlanResponseDto): Promise<boolean> {
    try {
      await this.plans.insert({
        id: plan.plan_id,
        user_id: userId,
        target_calories: plan.daily_target.target_calories,
        plan_json: plan,
        created_at: new Date(),
      });
      return true;
    } catch (error) {
      // Chỉ ghi thông báo lỗi của DB, không ghi nội dung plan (NFR-7).
      const message = error instanceof Error ? error.message : String(error);
      this.logger.error(`Không lưu được kế hoạch vào lịch sử: ${message}`);
      return false;
    }
  }

  // Đổi món/đổi bài/feedback ngày 1–2 cập nhật plan đã lưu (BRD FR-7, v2.5.0). plan_id của người khác,
  // hoặc plan tạo lúc chưa đăng nhập → không có dòng nào khớp, bỏ qua. Chỉ trả false khi DB lỗi.
  async update(userId: string, plan: MealPlanResponseDto): Promise<boolean> {
    try {
      await this.plans.update(
        { id: plan.plan_id, user_id: userId },
        { plan_json: plan, target_calories: plan.daily_target.target_calories },
      );
      return true;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.error(`Không cập nhật được kế hoạch trong lịch sử: ${message}`);
      return false;
    }
  }

  async list(userId: string): Promise<PlanHistoryResponseDto> {
    const records = await this.plans.find({
      select: { id: true, created_at: true, target_calories: true },
      where: { user_id: userId },
      order: { created_at: 'DESC', id: 'DESC' },
      take: HISTORY_LIMIT,
    });
    return {
      plans: records.map((record) => ({
        id: record.id,
        created_at: record.created_at.toISOString(),
        target_calories: record.target_calories,
      })),
    };
  }

  // Plan của người khác trả 404 giống plan không tồn tại, để không lộ là id đó có thật.
  async findOne(userId: string, planId: string): Promise<MealPlanResponseDto> {
    const record = await this.plans.findOne({
      select: { id: true, plan_json: true },
      where: { id: planId, user_id: userId },
    });
    if (!record) throw new NotFoundException('Không tìm thấy kế hoạch này trong lịch sử của bạn.');
    return record.plan_json;
  }
}
```

```bash
npx vitest run src/history/history.service.spec.ts   # Tests  9 passed (9)
```

### Task 5 — Cổng kiểm tra F02

```bash
cd backend_api
npm run typecheck
npm run build
npm test            # Test Files  20 passed (20) · Tests  196 passed (196)
npm run test:e2e    # Tests  37 passed (37)
```
