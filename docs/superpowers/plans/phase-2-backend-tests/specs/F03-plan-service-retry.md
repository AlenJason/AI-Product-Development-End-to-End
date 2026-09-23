# F03 — Test `PlanService` với Gemini giả: gọi lại, hết giờ, khoá sai, log

## Feature

Phủ toàn bộ nhánh của `PlanService.generateWithGemini()` mà giai đoạn 1 chưa test: kết quả hợp lệ → dùng luôn; sai hợp đồng → gọi lại 1 lần; sai tiếp → thực đơn mẫu; hết giờ → không gọi lại; khoá bị từ chối → gọi lại rồi thực đơn mẫu. Kèm một test cho ràng buộc #12: log không bao giờ chứa văn bản sức khoẻ người dùng nhập.

Ở tầng này `GeminiService` được thay bằng object giả (`vi.fn()`) để test chạy nhanh và tập trung vào logic điều phối; hành vi SDK thật đã được F02 kiểm.

## Scope

API-only (test) — `backend_api/src/plan/plan.service.spec.ts` (viết lại: giữ 3 test cũ, thêm 6 test).

## Implementation

### API Routes

Không đổi. Đây là logic sau `POST /api/v1/generate-plan`; latency tệ nhất đã ghi ở giai đoạn 1 (khoảng 30 giây: một lần trả sai + một lần hết giờ).

### UI Components

Không có.

### DB / KV Changes

Không có.

### Ràng buộc áp dụng

- **#2** kết quả sai hợp đồng → gọi lại 1 lần → thực đơn mẫu.
- **#12** log không chứa văn bản sức khoẻ — test theo dõi `Logger.prototype.warn/error`.
- **#15** hết giờ → không gọi lại.
- **#4** ESM: import có đuôi `.js`.

## Definition of Done

- [ ] 9 test pass (3 cũ + 6 mới)
- [ ] Số lần gọi Gemini được kiểm đúng ở mọi nhánh: 1 (hợp lệ), 2 (sai rồi đúng), 2 (sai hai lần), 1 (hết giờ), 2 (khoá sai)
- [ ] Log bị theo dõi có ít nhất 1 dòng, và không dòng nào chứa chuỗi sức khoẻ
- [x] All API routes complete within deployment timeout — không đổi route
- [x] Auth check at top of each protected handler — không áp dụng

## Test Checklist

1. **@happy**: Gemini trả nội dung hợp lệ → `source: gemini`, 1 lần gọi, không có cảnh báo "thực đơn mẫu"
2. **@auth**: không áp dụng
3. **@timeout**: `GeminiTimeoutError` → `source: sample`, đúng 1 lần gọi
4. **@partial-fail**: sai hợp đồng rồi đúng → `source: gemini`, 2 lần gọi; sai hai lần → `source: sample`, 2 lần gọi, có cảnh báo
5. **@token**: `ApiError` 400 hai lần → `source: sample`, 2 lần gọi
6. **@db**: không áp dụng

## Tasks

### Task 1 — Viết lại `backend_api/src/plan/plan.service.spec.ts`

```ts
import { Logger } from '@nestjs/common';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { CreatePlanDto } from './dto/create-plan.dto.js';
import { RestrictionsDto } from './dto/restrictions.dto.js';
import { ActivityLevel } from './enums/activity-level.enum.js';
import { Gender } from './enums/gender.enum.js';
import { Goal } from './enums/goal.enum.js';
import { GeminiTimeoutError, type GeminiService } from './gemini.service.js';
import { PlanService } from './plan.service.js';
import { WARNINGS } from './plan-warnings.js';

const SAMPLE_CONTENT: unknown = JSON.parse(
  readFileSync(fileURLToPath(new URL('./data/sample-plan.json', import.meta.url)), 'utf-8'),
);
const INVALID_CONTENT = { days: [] };
const SECRET = 'BENH-NEN-BI-MAT-123';

function profile(overrides: Partial<CreatePlanDto> = {}, restrictions: Partial<RestrictionsDto> = {}): CreatePlanDto {
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

const geminiOff = { isConfigured: false } as unknown as GeminiService;

// Gemini giả: mỗi phần tử là kết quả của một lần gọi — Error thì ném ra, còn lại thì trả về.
function geminiAnswering(...answers: unknown[]) {
  const generatePlanContent = vi.fn();
  for (const answer of answers) {
    if (answer instanceof Error) generatePlanContent.mockRejectedValueOnce(answer);
    else generatePlanContent.mockResolvedValueOnce(answer);
  }
  const gemini = { isConfigured: true, generatePlanContent } as unknown as GeminiService;
  return { gemini, generatePlanContent };
}

describe('PlanService.generatePlan without a Gemini key', () => {
  it('returns the 3-day sample plan with the computed daily target and no warnings', async () => {
    const plan = await new PlanService(geminiOff).generatePlan(profile());
    expect(plan.source).toBe('sample');
    expect(plan.days).toHaveLength(3);
    expect(plan.grocery_list.length).toBeGreaterThan(0);
    expect(plan.daily_target.target_calories).toBe(1624);
    expect(plan.warnings).toEqual([]);
  });

  it('warns that the sample is not filtered and adds the medical disclaimer', async () => {
    const plan = await new PlanService(geminiOff).generatePlan(
      profile({}, { allergies: 'Hải sản', health_conditions: 'Tiểu đường' }),
    );
    expect(plan.warnings).toContain(WARNINGS.sampleNotFiltered);
    expect(plan.warnings).toContain(WARNINGS.healthConditions);
  });

  it('explains when the target was raised to BMR', async () => {
    const plan = await new PlanService(geminiOff).generatePlan(
      profile({ height_cm: 150, weight_kg: 45, activity_level: ActivityLevel.SEDENTARY }),
    );
    expect(plan.daily_target.target_calories).toBe(1117);
    expect(plan.warnings).toContain(WARNINGS.bmrFloor(1117));
  });
});

describe('PlanService.generatePlan with Gemini configured', () => {
  afterEach(() => vi.restoreAllMocks());

  it('uses Gemini output that follows the contract', async () => {
    const { gemini, generatePlanContent } = geminiAnswering(SAMPLE_CONTENT);
    const plan = await new PlanService(gemini).generatePlan(profile({}, { allergies: 'Hải sản' }));
    expect(plan.source).toBe('gemini');
    expect(generatePlanContent).toHaveBeenCalledTimes(1);
    expect(plan.warnings).not.toContain(WARNINGS.sampleNotFiltered);
  });

  it('retries once when the first answer breaks the contract', async () => {
    const { gemini, generatePlanContent } = geminiAnswering(INVALID_CONTENT, SAMPLE_CONTENT);
    const plan = await new PlanService(gemini).generatePlan(profile());
    expect(plan.source).toBe('gemini');
    expect(generatePlanContent).toHaveBeenCalledTimes(2);
  });

  it('falls back to the sample after two answers that break the contract', async () => {
    const { gemini, generatePlanContent } = geminiAnswering(INVALID_CONTENT, INVALID_CONTENT);
    const plan = await new PlanService(gemini).generatePlan(profile({}, { allergies: 'Hải sản' }));
    expect(plan.source).toBe('sample');
    expect(generatePlanContent).toHaveBeenCalledTimes(2);
    expect(plan.warnings).toContain(WARNINGS.sampleNotFiltered);
  });

  it('does not retry after a timeout', async () => {
    const { gemini, generatePlanContent } = geminiAnswering(new GeminiTimeoutError(15_000), SAMPLE_CONTENT);
    const plan = await new PlanService(gemini).generatePlan(profile());
    expect(plan.source).toBe('sample');
    expect(generatePlanContent).toHaveBeenCalledTimes(1);
  });

  it('falls back to the sample when the API key is rejected', async () => {
    const keyRejected = Object.assign(new Error('API key not valid'), { name: 'ApiError', status: 400 });
    const { gemini, generatePlanContent } = geminiAnswering(keyRejected, keyRejected);
    const plan = await new PlanService(gemini).generatePlan(profile());
    expect(plan.source).toBe('sample');
    expect(generatePlanContent).toHaveBeenCalledTimes(2);
  });

  it('never writes the user health text to the log (#12)', async () => {
    const warn = vi.spyOn(Logger.prototype, 'warn').mockImplementation(() => undefined);
    const error = vi.spyOn(Logger.prototype, 'error').mockImplementation(() => undefined);
    const { gemini } = geminiAnswering(INVALID_CONTENT, new Error('boom'));

    await new PlanService(gemini).generatePlan(profile({}, { allergies: SECRET, health_conditions: SECRET }));

    const logged = [...warn.mock.calls, ...error.mock.calls].flat().map(String).join('\n');
    expect(warn).toHaveBeenCalled();
    expect(logged).not.toContain(SECRET);
  });
});
```

### Task 2 — Chạy

```bash
cd backend_api && npx vitest run src/plan/plan.service.spec.ts
```

Mong đợi: `Tests  9 passed (9)`. Code `plan.service.ts` đã có từ giai đoạn 1, nên các test mới xanh ngay nếu logic đúng như thiết kế. Nếu một test đỏ, đó là lỗi thật của `PlanService` — sửa code, **không** sửa test.
