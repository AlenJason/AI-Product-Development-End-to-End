# F04 — Ghép plan phía server: ID và danh sách đi chợ

## Feature

`assemblePlan()` biến nội dung đã qua kiểm tra (`PlanContentDto`, từ F02) thành `MealPlanResponseDto` hoàn chỉnh: gán `plan_id` (UUID), đánh số ngày, sắp bữa theo thứ tự sáng → trưa → tối, gán `meal_id` / `exercise_id` theo mẫu `m{ngày}_{thứ tự}` / `e{ngày}_{thứ tự}`, và **tự tính `grocery_list`** từ nguyên liệu của mọi món (hướng B, Q1). Nhờ vậy danh sách đi chợ luôn khớp thực đơn; giai đoạn 4 chỉ cần thay món rồi gọi lại `buildGroceryList()`.

## Scope

API-only — file mới:

- `backend_api/src/plan/plan-assembly.ts`
- `backend_api/src/plan/plan-assembly.spec.ts`

## Implementation

### API Routes

Chưa đổi route; F06 nối vào `POST /api/v1/generate-plan`.

### UI Components

Không có. Flutter (giai đoạn 6) hiển thị `quantity` nguyên văn và giữ trạng thái tích chọn theo `name` + `category`.

### DB / KV Changes

Không có.

### Ràng buộc áp dụng

- **#7 — có mâu thuẫn, đã có quyết định:** ràng buộc #7 hiện mô tả việc cập nhật từng phần theo `source_meal_ids`. Q1 chọn hướng B: server luôn tính lại toàn bộ. Feature này làm theo Q1; F07 viết lại ràng buộc #7.
- **#4** (ESM): import có đuôi `.js`.

## Definition of Done

- [ ] `plan_id` là UUID v4; `source`, `warnings`, `daily_target` giữ nguyên như truyền vào
- [ ] Bữa trong mỗi ngày được sắp breakfast → lunch → dinner, bất kể thứ tự Gemini trả về
- [ ] Nguyên liệu trùng tên (không phân biệt hoa thường, khoảng trắng) và cùng đơn vị được cộng dồn; `source_meal_ids` không lặp
- [ ] Cùng nguyên liệu khác đơn vị nằm ở hai dòng
- [ ] Nhóm theo thứ tự protein → produce → pantry, bỏ nhóm rỗng
- [ ] `npm run build` không lỗi, `npm test` xanh
- [x] All API routes complete within deployment timeout — không áp dụng (hàm thuần)
- [x] Auth check at top of each protected handler — không áp dụng

## Test Checklist

1. **@happy**: 3 ngày × (Gạo tẻ 100 g trưa + 80 g tối) → một dòng `540g` với 6 `source_meal_ids` đúng thứ tự
2. **@auth**: không áp dụng
3. **@timeout**: không áp dụng
4. **@partial-fail**: `Dầu ăn` 1 tbsp và `dầu ăn ` 1 tsp → hai dòng `1 muỗng canh`, `1 muỗng cà phê`
5. **@token**: không áp dụng
6. **@db**: không áp dụng

## Tasks

### Task 1 — Viết test trước

`backend_api/src/plan/plan-assembly.spec.ts`:

```ts
import type { DailyTargetDto } from './dto/meal-plan-response.dto.js';
import { IngredientUnit } from './enums/ingredient.enum.js';
import { PlanSource } from './enums/plan-source.enum.js';
import { assemblePlan, formatQuantity } from './plan-assembly.js';
import { parsePlanContent } from './plan-validation.js';

const target: DailyTargetDto = {
  bmi: 22,
  bmr: 1399,
  tdee: 1924,
  target_calories: 1624,
  protein_g: 102,
  carbs_g: 183,
  fat_g: 54,
};

const rice = (amount: number) => ({ name: 'Gạo tẻ', amount, unit: 'g', category: 'pantry' });

function meal(meal_type: string, name: string, ingredients: object[]) {
  return { meal_type, name, portion: '1 phần', calories: 500, protein_g: 30, carbs_g: 60, fat_g: 15, ingredients };
}

function day(n: number, lunchIngredients: object[]) {
  return {
    meals: [
      meal('dinner', `Tối ${n}`, [rice(80)]),
      meal('breakfast', `Sáng ${n}`, [{ name: 'Trứng gà', amount: 2, unit: 'piece', category: 'protein' }]),
      meal('lunch', `Trưa ${n}`, lunchIngredients),
    ],
    workout: {
      title: 'Tập',
      duration_minutes: 20,
      exercises: [
        { name: 'Squat', sets: 3, reps_or_duration: '12 lần', muscle_group: 'legs', tags: [] },
        { name: 'Plank', sets: 3, reps_or_duration: '30 giây', muscle_group: 'core', tags: [] },
      ],
    },
  };
}

function content() {
  const { plan, errors } = parsePlanContent({
    days: [
      day(1, [rice(100), { name: 'Rau muống', amount: 150, unit: 'g', category: 'produce' }]),
      day(2, [rice(100), { name: 'Dầu ăn', amount: 1, unit: 'tbsp', category: 'pantry' }]),
      day(3, [rice(100), { name: 'dầu ăn ', amount: 1, unit: 'tsp', category: 'pantry' }]),
    ],
  });
  if (!plan) throw new Error(`fixture không hợp lệ: ${errors.join('; ')}`);
  return plan;
}

describe('assemblePlan', () => {
  const plan = assemblePlan(content(), target, PlanSource.SAMPLE, ['cảnh báo']);

  it('assigns a UUID plan_id and keeps source, warnings and daily target', () => {
    expect(plan.plan_id).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[0-9a-f]{4}-[0-9a-f]{12}$/);
    expect(plan.source).toBe('sample');
    expect(plan.warnings).toEqual(['cảnh báo']);
    expect(plan.daily_target).toEqual(target);
  });

  it('orders meals breakfast → lunch → dinner and numbers ids by day', () => {
    expect(plan.days.map((d) => d.day_number)).toEqual([1, 2, 3]);
    expect(plan.days[1].meals.map((m) => [m.meal_id, m.meal_type])).toEqual([
      ['m2_1', 'breakfast'],
      ['m2_2', 'lunch'],
      ['m2_3', 'dinner'],
    ]);
    expect(plan.days[2].workout.exercises.map((e) => e.exercise_id)).toEqual(['e3_1', 'e3_2']);
  });
});

describe('grocery_list', () => {
  const grocery = assemblePlan(content(), target, PlanSource.SAMPLE, []).grocery_list;
  const items = (category: string, name: string) =>
    grocery
      .find((group) => group.category === category)
      ?.items.filter((item) => item.name.trim().toLowerCase() === name) ?? [];

  it('orders categories protein → produce → pantry', () => {
    expect(grocery.map((group) => group.category)).toEqual(['protein', 'produce', 'pantry']);
  });

  it('sums the same ingredient and unit across meals, listing each source meal once', () => {
    expect(items('pantry', 'gạo tẻ')).toEqual([
      {
        name: 'Gạo tẻ',
        quantity: '540g',
        source_meal_ids: ['m1_2', 'm1_3', 'm2_2', 'm2_3', 'm3_2', 'm3_3'],
      },
    ]);
    expect(items('protein', 'trứng gà')[0].quantity).toBe('×6');
  });

  it('keeps different units of the same ingredient on separate lines', () => {
    expect(items('pantry', 'dầu ăn').map((item) => item.quantity)).toEqual([
      '1 muỗng canh',
      '1 muỗng cà phê',
    ]);
  });
});

describe('formatQuantity', () => {
  it('formats every unit for display', () => {
    expect(formatQuantity(450, IngredientUnit.G)).toBe('450g');
    expect(formatQuantity(30, IngredientUnit.ML)).toBe('30ml');
    expect(formatQuantity(2, IngredientUnit.PIECE)).toBe('×2');
    expect(formatQuantity(1.25, IngredientUnit.TBSP)).toBe('1.3 muỗng canh');
    expect(formatQuantity(0.5, IngredientUnit.TSP)).toBe('0.5 muỗng cà phê');
  });
});
```

Chạy:

```bash
cd backend_api && npx vitest run src/plan/plan-assembly.spec.ts
```

Mong đợi: **FAIL** — `Cannot find module './plan-assembly.js'`.

### Task 2 — Ghép plan

`backend_api/src/plan/plan-assembly.ts`:

```ts
import { randomUUID } from 'node:crypto';
import type {
  DailyTargetDto,
  DayPlanDto,
  GroceryCategoryDto,
  GroceryItemDto,
  MealPlanResponseDto,
} from './dto/meal-plan-response.dto.js';
import type { PlanContentDto } from './dto/plan-content.dto.js';
import { IngredientCategory, IngredientUnit } from './enums/ingredient.enum.js';
import { MealType } from './enums/meal-type.enum.js';
import type { PlanSource } from './enums/plan-source.enum.js';
import { normalizeKey } from './text.util.js';

const MEAL_ORDER = [MealType.BREAKFAST, MealType.LUNCH, MealType.DINNER];
const CATEGORY_ORDER = [IngredientCategory.PROTEIN, IngredientCategory.PRODUCE, IngredientCategory.PANTRY];

interface GroceryEntry {
  name: string;
  unit: IngredientUnit;
  amount: number;
  mealIds: string[];
}

export function assemblePlan(
  content: PlanContentDto,
  dailyTarget: DailyTargetDto,
  source: PlanSource,
  warnings: string[],
): MealPlanResponseDto {
  const days: DayPlanDto[] = content.days.map((day, dayIndex) => {
    const dayNumber = dayIndex + 1;
    const meals = [...day.meals].sort(
      (a, b) => MEAL_ORDER.indexOf(a.meal_type) - MEAL_ORDER.indexOf(b.meal_type),
    );
    return {
      day_number: dayNumber,
      meals: meals.map((meal, mealIndex) => ({
        ...meal,
        calories: Math.round(meal.calories),
        meal_id: `m${dayNumber}_${mealIndex + 1}`,
      })),
      workout: {
        title: day.workout.title,
        duration_minutes: day.workout.duration_minutes,
        exercises: day.workout.exercises.map((exercise, exerciseIndex) => ({
          ...exercise,
          exercise_id: `e${dayNumber}_${exerciseIndex + 1}`,
        })),
      },
    };
  });

  return {
    plan_id: randomUUID(),
    source,
    warnings,
    daily_target: dailyTarget,
    days,
    grocery_list: buildGroceryList(days),
  };
}

// Danh sách đi chợ luôn tính lại từ nguyên liệu của mọi món, không lấy từ Gemini hay client (BRD FR-3.1, FR-4.1).
export function buildGroceryList(days: DayPlanDto[]): GroceryCategoryDto[] {
  const byCategory = new Map<IngredientCategory, Map<string, GroceryEntry>>();

  for (const day of days) {
    for (const meal of day.meals) {
      for (const ingredient of meal.ingredients) {
        const entries = byCategory.get(ingredient.category) ?? new Map<string, GroceryEntry>();
        byCategory.set(ingredient.category, entries);

        const key = `${normalizeKey(ingredient.name)}|${ingredient.unit}`;
        const entry = entries.get(key);
        if (!entry) {
          entries.set(key, {
            name: ingredient.name.trim(),
            unit: ingredient.unit,
            amount: ingredient.amount,
            mealIds: [meal.meal_id],
          });
          continue;
        }
        entry.amount += ingredient.amount;
        if (!entry.mealIds.includes(meal.meal_id)) entry.mealIds.push(meal.meal_id);
      }
    }
  }

  return CATEGORY_ORDER.flatMap((category) => {
    const entries = byCategory.get(category);
    if (!entries) return [];
    const items: GroceryItemDto[] = [...entries.values()].map((entry) => ({
      name: entry.name,
      quantity: formatQuantity(entry.amount, entry.unit),
      source_meal_ids: entry.mealIds,
    }));
    return [{ category, items }];
  });
}

export function formatQuantity(amount: number, unit: IngredientUnit): string {
  const value = String(Math.round(amount * 10) / 10);
  switch (unit) {
    case IngredientUnit.G:
      return `${value}g`;
    case IngredientUnit.ML:
      return `${value}ml`;
    case IngredientUnit.PIECE:
      return `×${value}`;
    case IngredientUnit.TBSP:
      return `${value} muỗng canh`;
    case IngredientUnit.TSP:
      return `${value} muỗng cà phê`;
  }
}
```

### Task 3 — Chạy lại

```bash
cd backend_api && npx vitest run src/plan/plan-assembly.spec.ts
cd backend_api && npm run build && npm test
```

Mong đợi: `Test Files  1 passed (1)`, `Tests  6 passed (6)`; build không lỗi; `npm test` xanh toàn bộ.
