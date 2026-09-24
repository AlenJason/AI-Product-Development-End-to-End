# F06 — Ba endpoint, lịch sử, e2e, smoke test

## Feature

Nối F02–F05 thành ba route HTTP (BRD 6.4):

| Route | Service | Thành công |
|---|---|---|
| `POST /api/v1/meals/swap` | `MealSwapService` | 200 `{ plan }` |
| `POST /api/v1/exercises/swap` | `ExerciseSwapService` | 200 `{ plan }` |
| `POST /api/v1/feedback` | `FeedbackService` | 200 `{ plan, safety_warning }` |

Cả ba dùng `OptionalJwtAuthGuard` như `generate-plan` (quyết định Q4):

- không gửi token → chạy như khách;
- token sai → 401;
- token hợp lệ → đổi món, đổi bài, feedback ngày 1–2 gọi `HistoryService.update()`; feedback ngày 3 gọi `save()`.

Ghi lỗi → vẫn trả plan, thêm `historyNotSaved` (#22).

E2E chạy qua HTTP thật: ba endpoint ở chế độ giả lập, các lỗi 400/409/422/401, lịch sử, #12, Swagger, và một đường đổi món qua SDK `@google/genai` thật tới server Gemini giả. Smoke test gọi thêm ba endpoint trên bản build. Ba file JSON mới chỉ được bản build đọc lúc chạy, nên thiếu chúng thì smoke test đỏ; đã kiểm bằng cách xoá `dist/plan/data/swap-meals.json`.

Tắt quy tắc lint `typescript/no-misused-spread`. Quy tắc này bảo vệ class có method hoặc getter; DTO của dự án chỉ chứa dữ liệu, và code cố ý chép chúng thành object thường khi dựng response. Giai đoạn 4 làm số cảnh báo loại này tăng từ 2 lên 27, che mất cảnh báo thật. Sau khi tắt, `npm run lint` không còn cảnh báo nào.

## Scope

API + CI:

- `backend_api/src/plan/adjust/plan-adjust.controller.ts` (mới)
- `backend_api/src/plan/plan.module.ts` (sửa)
- `backend_api/test/adjust.e2e-spec.ts` (mới)
- `backend_api/scripts/smoke-test.mjs` (sửa)
- `backend_api/.oxlintrc.json` (sửa)

## Implementation

### API Routes

| Route | Lỗi | Độ trễ |
|---|---|---|
| `meals/swap` | 400, 401, 409, 422 | kho ~6 ms; Gemini tệ nhất 30 s |
| `exercises/swap` | 400, 401, 409, 422 | kho ~4 ms; Gemini tệ nhất 30 s |
| `feedback` | 400, 401, 409 | ngày 1–2 không Gemini ~4 ms; ngày 3 / có cân đối món ăn tệ nhất ~30 s |

Mỗi route cộng thêm tối đa 1 truy vấn xác thực + 1 `UPDATE`/`INSERT` khi đã đăng nhập (< 5 ms).

**Auth check:** `@UseGuards(OptionalJwtAuthGuard)` ở cấp class, nên áp cho cả ba route. Guard chạy trước `ValidationPipe`: token sai → 401 trước mọi lỗi 400.

### UI Components

Không có. Swagger có đủ ba route, schema `PlanEnvelopeDto`, `FeedbackResponseDto`.

### DB / KV Changes

Không đổi schema. Ghi `plan_records` qua `update()` (F02) và `save()` (giai đoạn 3).

### Ràng buộc áp dụng

- **#12** e2e kiểm response và dòng trong DB không chứa chuỗi dị ứng bí mật.
- **#17** e2e dùng `createTestApp()`, không Gemini thật; đường Gemini dùng server giả.
- **#18** không thêm cấu hình toàn cục.
- **#20** smoke test gọi cả ba endpoint trên bản build.
- **#22** 401 khi token sai; không đụng plan của người khác; ghi lỗi vẫn trả plan.

## Definition of Done

- [ ] `npm run test:e2e` → `Test Files  5 passed (5)`, `Tests  58 passed (58)`
- [ ] `npm test` → `Test Files  24 passed (24)`, `Tests  240 passed (240)`
- [ ] `npm run build && npm run test:smoke` → `Smoke test đạt: /health, đăng nhập giả lập, generate-plan, lịch sử, đổi món, đổi bài tập, feedback.`
- [ ] `npm run lint` không in cảnh báo nào
- [ ] All API routes complete within deployment timeout — bảng độ trễ ở trên
- [ ] Auth check at top of each protected handler — `OptionalJwtAuthGuard` ở cấp class

## Test Checklist

1. **@happy**:
   - đổi món → `plan_id` giữ, món khác, cùng calo;
   - đổi bài → cùng nhóm cơ;
   - feedback ngày 1 → ngày 2 ngắn hơn;
   - ngày 3 → `plan_id` mới;
   - qua SDK thật + server Gemini giả → món Gemini đề xuất, đúng 1 request, request có khối `du_lieu_nguoi_dung`
2. **@auth**: token sai → 401; đăng nhập → lịch sử cập nhật (xem lại bằng `GET /plans/history/:id` ra đúng plan mới); người khác gửi plan đó → plan của chủ không đổi; khách → không ghi gì
3. **@timeout**: server Gemini giả không trả lời → dùng kho, đúng 1 request
4. **@partial-fail**: 400 cho 7 kiểu request sai (`meal_id` sai dạng, plan sửa tay, `body_states` rỗng, ngày 4, thiếu `plan`, thiếu `profile`, `plan` không phải object); 409 khi hồ sơ đổi; 422 khi động tác đã nhẹ nhất
5. **@token**: token sai ở cả ba route → 401, không âm thầm bỏ qua lịch sử
6. **@db**: feedback ngày 3 → lịch sử có 2 plan, mới nhất trước; response và `plan_json` trong DB không chứa chuỗi dị ứng bí mật

## Tasks

### Task 1 — E2E trước (đỏ)

`backend_api/test/adjust.e2e-spec.ts`:

```ts
import { readFileSync } from 'node:fs';
import request from 'supertest';
import { DataSource } from 'typeorm';
import { startFakeGemini, type FakeGemini } from './fake-gemini-server.js';
import { createTestApp, loginMock, type TestApp } from './test-app.js';

const SECRET = 'DI-UNG-BI-MAT-321';
const PROFILE = {
  age: 22,
  gender: 'female',
  height_cm: 168,
  weight_kg: 62,
  activity_level: 'light',
  goal: 'cut',
  restrictions: { allergies: SECRET, injuries: '', health_conditions: '' },
};

describe('Đổi món, đổi bài tập, feedback (e2e, chế độ giả lập)', () => {
  let testApp: TestApp;
  const http = () => request(testApp.app.getHttpServer());
  const post = (path: string, body: object, token?: string) => {
    const req = http().post(`/api/v1/${path}`);
    if (token) req.set('Authorization', `Bearer ${token}`);
    return req.send(body);
  };
  const generate = async (token?: string) => (await post('generate-plan', PROFILE, token).expect(200)).body;
  const storedPlan = async (id: string) => {
    const rows: { plan_json: string }[] = await testApp.app
      .get(DataSource)
      .query('SELECT plan_json FROM plan_records WHERE id = ?', [id]);
    return rows[0] ? JSON.parse(rows[0].plan_json) : undefined;
  };

  beforeAll(async () => {
    testApp = await createTestApp();
  });

  afterAll(async () => {
    await testApp.close();
  });

  it('swaps a meal and keeps the plan id (FR-4.1)', async () => {
    const plan = await generate();
    const { body } = await post('meals/swap', { profile: PROFILE, plan, meal_id: 'm2_2' }).expect(200);
    expect(body.plan.plan_id).toBe(plan.plan_id);
    expect(body.plan.days[1].meals[1].name).not.toBe(plan.days[1].meals[1].name);
    expect(body.plan.days[1].meals[1].calories).toBe(plan.days[1].meals[1].calories);
  });

  it('swaps an exercise for a lighter one (FR-4.2), or answers 422 when none is lighter', async () => {
    const plan = await generate();
    const { body } = await post('exercises/swap', { profile: PROFILE, plan, exercise_id: 'e1_2' }).expect(200);
    expect(body.plan.days[0].workout.exercises[1].muscle_group).toBe('legs');
    expect(body.plan.days[0].workout.exercises[1].name).not.toBe(plan.days[0].workout.exercises[1].name);
    await post('exercises/swap', { profile: PROFILE, plan, exercise_id: 'e3_2' }).expect(422);
  });

  it('adjusts the next day after feedback (FR-5.2)', async () => {
    const plan = await generate();
    const { body } = await post('feedback', {
      profile: PROFILE,
      plan,
      day_number: 1,
      intensity: 'hard',
      body_states: ['sore'],
      eating: 'on_plan',
    }).expect(200);
    expect(body.safety_warning).toBeNull();
    expect(body.plan.days[1].workout.duration_minutes).toBeLessThan(plan.days[1].workout.duration_minutes);
  });

  it('answers a danger sign with a safety warning and a rest day (#14)', async () => {
    const plan = await generate();
    const { body } = await post('feedback', {
      profile: PROFILE,
      plan,
      day_number: 2,
      intensity: 'easy',
      body_states: ['danger_sign'],
      eating: 'over',
    }).expect(200);
    expect(body.safety_warning.message).toContain('115');
    expect(body.plan.days[2].workout.title).toContain('Nghỉ ngơi');
  });

  it('creates a new plan after feedback on day 3 (FR-5.3)', async () => {
    const plan = await generate();
    const { body } = await post('feedback', {
      profile: PROFILE,
      plan,
      day_number: 3,
      intensity: 'moderate',
      body_states: ['normal'],
      eating: 'on_plan',
    }).expect(200);
    expect(body.plan.plan_id).not.toBe(plan.plan_id);
    expect(body.plan.days).toHaveLength(3);
  });

  it.each<[string, string, (plan: Record<string, unknown>) => object]>([
    ['a malformed meal_id', 'meals/swap', (plan) => ({ profile: PROFILE, plan, meal_id: 'x1_2' })],
    ['a plan edited by hand', 'meals/swap', (plan) => {
      const edited = structuredClone(plan) as { days: { meals: { calories: number }[] }[] };
      edited.days[0].meals[0].calories = 5000;
      return { profile: PROFILE, plan: edited, meal_id: 'm1_1' };
    }],
    ['no body state', 'feedback', (plan) => ({ profile: PROFILE, plan, day_number: 1, intensity: 'hard', body_states: [], eating: 'on_plan' })],
    ['day 4', 'feedback', (plan) => ({ profile: PROFILE, plan, day_number: 4, intensity: 'hard', body_states: ['normal'], eating: 'on_plan' })],
    ['no plan', 'exercises/swap', () => ({ profile: PROFILE, exercise_id: 'e1_1' })],
    ['no profile', 'meals/swap', (plan) => ({ plan, meal_id: 'm1_1' })],
    ['a plan that is not an object', 'meals/swap', () => ({ profile: PROFILE, plan: 'abc', meal_id: 'm1_1' })],
  ])('answers 400 to %s', async (_label, path, build) => {
    await post(path, build(await generate())).expect(400);
  });

  it('answers 409 when the profile changed since the plan was made', async () => {
    const plan = await generate();
    await post('meals/swap', { profile: { ...PROFILE, goal: 'bulk' }, plan, meal_id: 'm1_1' }).expect(409);
  });

  it('never returns or stores the restriction text (#12)', async () => {
    const { access_token } = await loginMock(testApp, 'bi-mat@vku.edu.vn');
    const plan = await generate(access_token);
    const swapped = await post('meals/swap', { profile: PROFILE, plan, meal_id: 'm1_1' }, access_token).expect(200);
    expect(JSON.stringify(swapped.body)).not.toContain(SECRET);
    expect(JSON.stringify(await storedPlan(plan.plan_id))).not.toContain(SECRET);
  });

  describe('lịch sử (quyết định Q4)', () => {
    it('updates the saved plan after a swap when logged in', async () => {
      const { access_token } = await loginMock(testApp, 'an@vku.edu.vn');
      const plan = await generate(access_token);
      const { body } = await post('meals/swap', { profile: PROFILE, plan, meal_id: 'm3_3' }, access_token).expect(200);
      const history = await http().get(`/api/v1/plans/history/${plan.plan_id}`).set('Authorization', `Bearer ${access_token}`).expect(200);
      expect(history.body.days[2].meals[2].name).toBe(body.plan.days[2].meals[2].name);
      expect(history.body).toEqual(body.plan);
    });

    it('saves the new plan from day-3 feedback as a new history entry', async () => {
      const { access_token } = await loginMock(testApp, 'binh@vku.edu.vn');
      const plan = await generate(access_token);
      const { body } = await post(
        'feedback',
        { profile: PROFILE, plan, day_number: 3, intensity: 'easy', body_states: ['normal'], eating: 'on_plan' },
        access_token,
      ).expect(200);
      const history = await http().get('/api/v1/plans/history').set('Authorization', `Bearer ${access_token}`).expect(200);
      expect(history.body.plans.map((p: { id: string }) => p.id)).toEqual([body.plan.plan_id, plan.plan_id]);
    });

    it("never touches another user's saved plan, and a guest swap stores nothing", async () => {
      const owner = await loginMock(testApp, 'chu@vku.edu.vn');
      const other = await loginMock(testApp, 'khac@vku.edu.vn');
      const plan = await generate(owner.access_token);
      await post('meals/swap', { profile: PROFILE, plan, meal_id: 'm1_1' }, other.access_token).expect(200);
      await post('meals/swap', { profile: PROFILE, plan, meal_id: 'm1_1' }).expect(200);
      expect(await storedPlan(plan.plan_id)).toEqual(plan);
    });

    it('answers 401 to a bad token instead of skipping history', async () => {
      const plan = await generate();
      await post('meals/swap', { profile: PROFILE, plan, meal_id: 'm1_1' }, 'not-a-jwt').expect(401);
    });
  });

  it('documents the three endpoints in Swagger', async () => {
    const { body } = await http().get('/docs-json').expect(200);
    expect(Object.keys(body.paths)).toEqual(
      expect.arrayContaining(['/api/v1/meals/swap', '/api/v1/exercises/swap', '/api/v1/feedback']),
    );
    expect(body.components.schemas).toHaveProperty('FeedbackResponseDto');
  });
});

describe('Đổi món qua SDK thật + server Gemini giả (e2e)', () => {
  const SAMPLE_CONTENT: unknown = JSON.parse(
    readFileSync(new URL('../src/plan/data/sample-plan.json', import.meta.url), 'utf-8'),
  );
  const PROFILE_OK = { ...PROFILE, restrictions: { allergies: 'Đậu phộng', injuries: '', health_conditions: '' } };
  let testApp: TestApp;
  let fake: FakeGemini;

  beforeAll(async () => {
    fake = await startFakeGemini();
    testApp = await createTestApp({ GEMINI_API_KEY: 'test-key', GEMINI_BASE_URL: fake.url, GEMINI_TIMEOUT_MS: '200' });
  });

  afterAll(async () => {
    await testApp.close();
    await fake.close();
  });

  it('uses the dish Gemini suggests when it passes every check', async () => {
    fake.reply({ kind: 'json', body: SAMPLE_CONTENT });
    const { body: plan } = await request(testApp.app.getHttpServer()).post('/api/v1/generate-plan').send(PROFILE_OK).expect(200);
    const lunch = plan.days[0].meals[1];

    fake.reply({
      kind: 'json',
      body: {
        meal_type: 'lunch',
        name: 'Cơm cá hồi áp chảo, canh bí',
        portion: '1 chén cơm + 1 miếng cá',
        calories: lunch.calories,
        protein_g: (lunch.calories * 0.25) / 4,
        carbs_g: (lunch.calories * 0.5) / 4,
        fat_g: (lunch.calories * 0.25) / 9,
        ingredients: [{ name: 'Cá hồi', amount: 120, unit: 'g', category: 'protein' }],
      },
    });
    const { body } = await request(testApp.app.getHttpServer())
      .post('/api/v1/meals/swap')
      .send({ profile: PROFILE_OK, plan, meal_id: 'm1_2' })
      .expect(200);
    expect(fake.requests).toHaveLength(1);
    expect(fake.requests[0]).toContain('du_lieu_nguoi_dung');
    expect(body.plan.days[0].meals[1].name).toBe('Cơm cá hồi áp chảo, canh bí');
  });

  it('falls back to the pool after a Gemini timeout, without retrying (#15)', async () => {
    fake.reply({ kind: 'json', body: SAMPLE_CONTENT });
    const { body: plan } = await request(testApp.app.getHttpServer()).post('/api/v1/generate-plan').send(PROFILE_OK).expect(200);
    fake.reply({ kind: 'hang' });
    const { body } = await request(testApp.app.getHttpServer())
      .post('/api/v1/meals/swap')
      .send({ profile: PROFILE_OK, plan, meal_id: 'm1_2' })
      .expect(200);
    expect(fake.requests).toHaveLength(1);
    expect(body.plan.days[0].meals[1].name).not.toBe(plan.days[0].meals[1].name);
  });
});
```

```bash
cd backend_api
npx vitest run --config ./vitest.config.e2e.ts test/adjust.e2e-spec.ts   # đỏ: route chưa có (404)
```

### Task 2 — Controller và module

`backend_api/src/plan/adjust/plan-adjust.controller.ts`:

```ts
import { Body, Controller, HttpCode, HttpStatus, Post, UseGuards } from '@nestjs/common';
import {
  ApiBadRequestResponse,
  ApiBearerAuth,
  ApiConflictResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
  ApiUnauthorizedResponse,
  ApiUnprocessableEntityResponse,
} from '@nestjs/swagger';
import { CurrentUser, OptionalJwtAuthGuard } from '../../auth/jwt-auth.guard.js';
import type { User } from '../../database/entities/user.entity.js';
import { HistoryService } from '../../history/history.service.js';
import { FeedbackDto, FeedbackResponseDto, PlanEnvelopeDto, SwapExerciseDto, SwapMealDto } from '../dto/adjust-plan.dto.js';
import type { MealPlanResponseDto } from '../dto/meal-plan-response.dto.js';
import { WARNINGS } from '../plan-warnings.js';
import { ExerciseSwapService } from './exercise-swap.service.js';
import { FeedbackService } from './feedback.service.js';
import { MealSwapService } from './meal-swap.service.js';

// Đổi món, đổi bài tập, feedback (BRD mục 6.4). Đăng nhập tuỳ chọn như generate-plan: có token hợp lệ thì
// cập nhật plan đã lưu (hoặc lưu mới plan từ feedback ngày 3) — quyết định Q4 giai đoạn 4.
@ApiTags('plan')
@ApiBearerAuth()
@ApiBadRequestResponse({ description: 'Request hoặc plan gửi lên sai hợp đồng, hoặc ID không có trong plan' })
@ApiConflictResponse({ description: 'Plan được tạo cho hồ sơ khác (mục tiêu calo đã đổi) — cần tạo plan mới' })
@ApiUnauthorizedResponse({ description: 'Có gửi token nhưng token sai, hết hạn, hoặc tài khoản đã bị xoá' })
@UseGuards(OptionalJwtAuthGuard)
@Controller('api/v1')
export class PlanAdjustController {
  constructor(
    private readonly meals: MealSwapService,
    private readonly exercises: ExerciseSwapService,
    private readonly feedback: FeedbackService,
    private readonly history: HistoryService,
  ) {}

  @Post('meals/swap')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Đổi một món, calo lệch ≤ ±10% (BRD FR-4.1)' })
  @ApiOkResponse({ type: PlanEnvelopeDto })
  @ApiUnprocessableEntityResponse({ description: 'Không còn món thay thế phù hợp' })
  async swapMeal(@Body() dto: SwapMealDto, @CurrentUser() user: User | undefined): Promise<PlanEnvelopeDto> {
    return { plan: await this.record(user, await this.meals.swap(dto), false) };
  }

  @Post('exercises/swap')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Đổi một động tác sang động tác nhẹ hơn, cùng nhóm cơ (BRD FR-4.2)' })
  @ApiOkResponse({ type: PlanEnvelopeDto })
  @ApiUnprocessableEntityResponse({ description: 'Không còn động tác nhẹ hơn phù hợp' })
  async swapExercise(@Body() dto: SwapExerciseDto, @CurrentUser() user: User | undefined): Promise<PlanEnvelopeDto> {
    return { plan: await this.record(user, await this.exercises.swap(dto), false) };
  }

  @Post('feedback')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Feedback cuối ngày: điều chỉnh ngày kế tiếp, ngày 3 tạo plan mới (BRD FR-5)' })
  @ApiOkResponse({ type: FeedbackResponseDto })
  async submitFeedback(@Body() dto: FeedbackDto, @CurrentUser() user: User | undefined): Promise<FeedbackResponseDto> {
    const { response, isNewPlan } = await this.feedback.apply(dto);
    return { ...response, plan: await this.record(user, response.plan, isNewPlan) };
  }

  private async record(user: User | undefined, plan: MealPlanResponseDto, isNew: boolean): Promise<MealPlanResponseDto> {
    if (!user) return plan;
    const saved = isNew ? await this.history.save(user.id, plan) : await this.history.update(user.id, plan);
    if (!saved) plan.warnings.push(WARNINGS.historyNotSaved);
    return plan;
  }
}
```

`backend_api/src/plan/plan.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { HistoryModule } from '../history/history.module.js';
import { ExerciseSwapService } from './adjust/exercise-swap.service.js';
import { FeedbackService } from './adjust/feedback.service.js';
import { MealSwapService } from './adjust/meal-swap.service.js';
import { PlanAdjustController } from './adjust/plan-adjust.controller.js';
import { RandomSource } from './adjust/random-source.js';
import { PlanController } from './plan.controller.js';
import { PlanService } from './plan.service.js';
import { GeminiService } from './gemini.service.js';

@Module({
  imports: [AuthModule, HistoryModule],
  controllers: [PlanController, PlanAdjustController],
  providers: [PlanService, GeminiService, MealSwapService, ExerciseSwapService, FeedbackService, RandomSource],
})
export class PlanModule {}
```

```bash
npx vitest run --config ./vitest.config.e2e.ts test/adjust.e2e-spec.ts   # Tests  21 passed (21)
```

### Task 3 — Smoke test gọi ba endpoint mới

`backend_api/scripts/smoke-test.mjs`:

```js
// Chạy bản build (dist/) như server thật rồi gọi thử các endpoint chính.
// Bắt những lỗi vitest không thấy vì vitest chạy thẳng file .ts: asset chưa được copy vào dist
// (nest-cli.json), import vòng giữa các entity khi chạy ESM đã build.
// Không cần khoá nào: DB trong RAM, đăng nhập giả lập, không có Gemini (#17).
import { spawn } from 'node:child_process';

const PORT = process.env.SMOKE_PORT ?? '3999';
const BASE = `http://127.0.0.1:${PORT}`;
const STARTUP_TIMEOUT_MS = 20_000;

const server = spawn(process.execPath, ['dist/main.js'], {
  env: {
    ...process.env,
    PORT,
    NODE_ENV: 'test',
    DATABASE_PATH: ':memory:',
    AUTH_MODE: 'mock',
    GOOGLE_CLIENT_ID: '',
    JWT_SECRET: '',
    JWT_EXPIRES_IN: '',
    ALLOW_MOCK_AUTH: '',
    GEMINI_API_KEY: '',
    GEMINI_BASE_URL: '',
  },
  stdio: ['ignore', 'pipe', 'pipe'],
});
let output = '';
server.stdout.on('data', (chunk) => (output += chunk));
server.stderr.on('data', (chunk) => (output += chunk));
const exited = new Promise((resolve) => server.on('exit', resolve));

async function call(method, path, { token, body } = {}) {
  const res = await fetch(BASE + path, {
    method,
    headers: {
      ...(body ? { 'content-type': 'application/json' } : {}),
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : null };
}

function expect(condition, message) {
  if (!condition) throw new Error(message);
}

async function waitForServer() {
  const deadline = Date.now() + STARTUP_TIMEOUT_MS;
  while (Date.now() < deadline) {
    if (server.exitCode !== null) throw new Error(`Server thoát sớm (mã ${server.exitCode})`);
    try {
      return await call('GET', '/health');
    } catch {
      await new Promise((resolve) => setTimeout(resolve, 200));
    }
  }
  throw new Error(`Server không lên sau ${STARTUP_TIMEOUT_MS} ms`);
}

try {
  const health = await waitForServer();
  expect(health.status === 200 && health.body.auth_mode === 'mock', `/health sai: ${JSON.stringify(health)}`);

  const login = await call('POST', '/api/v1/auth/google', { body: { id_token: 'mock:smoke@vku.edu.vn' } });
  expect(login.status === 200 && login.body.access_token, `Đăng nhập giả lập lỗi: ${login.status}`);
  const token = login.body.access_token;

  const profile = { age: 22, gender: 'female', height_cm: 168, weight_kg: 62, activity_level: 'light', goal: 'cut' };
  const plan = await call('POST', '/api/v1/generate-plan', { token, body: profile });
  expect(plan.status === 200 && plan.body.source === 'sample', `generate-plan lỗi: ${plan.status}`);

  const history = await call('GET', '/api/v1/plans/history', { token });
  expect(history.status === 200 && history.body.plans[0]?.id === plan.body.plan_id, 'Plan không có trong lịch sử');

  const detail = await call('GET', `/api/v1/plans/history/${plan.body.plan_id}`, { token });
  expect(detail.status === 200 && detail.body.plan_id === plan.body.plan_id, `Xem lại plan lỗi: ${detail.status}`);

  // Giai đoạn 4: ba endpoint này đọc swap-meals.json, swap-exercises.json, restriction-keywords.json từ dist/.
  const adjust = { profile, plan: plan.body };
  const meal = await call('POST', '/api/v1/meals/swap', { token, body: { ...adjust, meal_id: 'm1_2' } });
  expect(meal.status === 200 && meal.body.plan.plan_id === plan.body.plan_id, `Đổi món lỗi: ${meal.status}`);
  const exercise = await call('POST', '/api/v1/exercises/swap', { token, body: { ...adjust, exercise_id: 'e1_2' } });
  expect(exercise.status === 200, `Đổi bài tập lỗi: ${exercise.status}`);
  const feedback = await call('POST', '/api/v1/feedback', {
    token,
    body: { ...adjust, day_number: 1, intensity: 'hard', body_states: ['danger_sign'], eating: 'on_plan' },
  });
  expect(feedback.status === 200 && feedback.body.safety_warning, `Feedback lỗi: ${feedback.status}`);

  console.log('Smoke test đạt: /health, đăng nhập giả lập, generate-plan, lịch sử, đổi món, đổi bài tập, feedback.');
} catch (error) {
  console.error(`Smoke test thất bại: ${error.message}\n--- log server ---\n${output}`);
  process.exitCode = 1;
} finally {
  server.kill();
  await exited;
}
```

Kiểm ngược: xoá một file dữ liệu khỏi bản build → smoke test phải đỏ.

```bash
npm run build && npm run test:smoke        # đạt
rm dist/plan/data/swap-meals.json && npm run test:smoke; echo "exit=$?"   # Server thoát sớm … ENOENT … exit=1
npm run build                              # dựng lại dist đầy đủ
```

### Task 4 — Lint

`backend_api/.oxlintrc.json`:

```json
{
  "$schema": "./node_modules/oxlint/configuration_schema.json",
  "rules": {
    "typescript/no-explicit-any": "off",
    "typescript/no-misused-spread": "off",
    "typescript/no-floating-promises": "error"
  },
  "env": {
    "node": true
  }
}
```

```bash
npm run lint   # không in cảnh báo nào
```

### Task 5 — Cổng kiểm tra F06

```bash
cd backend_api
npm run typecheck
npm run build
npm test             # Test Files  24 passed (24) · Tests  240 passed (240)
npm run test:e2e     # Test Files  5 passed (5) · Tests  58 passed (58)
npm run test:smoke   # … đổi món, đổi bài tập, feedback.
npm run lint
```
