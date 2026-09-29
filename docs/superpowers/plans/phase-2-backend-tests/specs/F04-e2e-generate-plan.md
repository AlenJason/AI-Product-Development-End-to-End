# F04 — `configureApp()` dùng chung + e2e `POST /api/v1/generate-plan`

## Feature

Hai việc:

1. Tách cấu hình app đang nằm trong `main.ts` (`ValidationPipe`, Swagger) ra `configureApp()` ở `src/app.setup.ts`. `main.ts` và test e2e cùng gọi hàm này, nên e2e chạy đúng như server thật và không lệch dần khi ai đó sửa `main.ts`.
2. E2E cho `POST /api/v1/generate-plan` chạy trọn đường: HTTP → `ValidationPipe` → `PlanService` → `GeminiService` → **SDK thật** → server Gemini giả (F02). Kiểm: kết quả Gemini hợp lệ, gọi lại rồi dùng thực đơn mẫu, hết giờ không gọi lại, 5 kiểu request sai → 400, request không có `restrictions` → 200, response không trả lại văn bản sức khoẻ, Swagger có schema response.

Test ghim `GEMINI_API_KEY`, `GEMINI_BASE_URL`, `GEMINI_TIMEOUT_MS` **trước khi nạp `AppModule`**, vì máy dev có thể có khoá thật trong `.env`. `@nestjs/config` ưu tiên biến môi trường có sẵn hơn file `.env`, và nạp `AppModule` bằng `import()` động bảo đảm việc ghim xảy ra trước khi `ConfigModule.forRoot()` chạy.

## Scope

API-only:

- `backend_api/src/app.setup.ts` (mới)
- `backend_api/src/main.ts` (dùng `configureApp()`)
- `backend_api/test/generate-plan.e2e-spec.ts` (mới)

## Implementation

### API Routes

`POST /api/v1/generate-plan`, `GET /docs-json` — không đổi hành vi. Latency trong e2e: đường Gemini giả vài chục ms; test hết giờ ~200 ms (`GEMINI_TIMEOUT_MS=200`); toàn file dưới 5 giây. Latency thật khi deploy như giai đoạn 1 (tệ nhất ~30 s).

**Khoá API bên ngoài:** khoá giả `test-key` gửi tới server giả; không test nào cần khoá thật hay gọi Google.

### UI Components

Không có.

### DB / KV Changes

Không có.

### Ràng buộc áp dụng

- **#3** khoá qua `.env`/`ConfigService` — e2e ghim biến môi trường, không đọc khoá thật.
- **#12** response không chứa văn bản sức khoẻ (văn bản vẫn được gửi cho Gemini — đúng thiết kế).
- **#15** hết giờ → 1 request, không gọi lại.
- **#16** `plan_id` là UUID do server gán dù Gemini không gửi.
- **#4** ESM: import có đuôi `.js`.

## Definition of Done

- [ ] `main.ts` chỉ còn tạo app, gọi `configureApp()`, `listen()`
- [ ] 11 test trong `generate-plan.e2e-spec.ts` pass; `npm run test:e2e` → `Tests  12 passed (12)` (tính cả test `/health`)
- [ ] Không test nào gửi request ra ngoài máy (server giả nghe `127.0.0.1`)
- [ ] Biến môi trường được khôi phục sau khi chạy
- [ ] `npm run build` không lỗi; server thật (`npm run start`) vẫn trả 400 cho `restrictions` kiểu mảng — cấu hình không mất khi tách hàm
- [ ] All API routes complete within deployment timeout — e2e toàn file < 5 s
- [x] Auth check at top of each protected handler — không áp dụng (`generate-plan` chưa cần đăng nhập)

## Test Checklist

1. **@happy**: server giả trả thực đơn hợp lệ → 200, `source: gemini`, UUID, 3 ngày, `daily_target` đúng ví dụ BRD, 3 nhóm đi chợ, 1 request
2. **@auth**: không áp dụng
3. **@timeout**: server giả không trả lời → 200, `source: sample`, đúng 1 request
4. **@partial-fail**: server giả trả sai hợp đồng → 2 request → `source: sample` + cảnh báo; 5 kiểu request sai → 400
5. **@token**: (khoá bị từ chối đã phủ ở F02, F03)
6. **@db**: không áp dụng

## Tasks

### Task 1 — Viết e2e trước

`backend_api/test/generate-plan.e2e-spec.ts`:

```ts
import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { readFileSync } from 'node:fs';
import request from 'supertest';
import type { App } from 'supertest/types';
import { configureApp } from '../src/app.setup.js';
import { startFakeGemini, type FakeGemini } from './fake-gemini-server.js';

const SAMPLE_CONTENT: unknown = JSON.parse(
  readFileSync(new URL('../src/plan/data/sample-plan.json', import.meta.url), 'utf-8'),
);
const SECRET = 'BENH-NEN-BI-MAT-123';
const BASE = { age: 22, gender: 'female', height_cm: 168, weight_kg: 62, activity_level: 'light', goal: 'cut' };
const body = (overrides: object = {}) => ({
  ...BASE,
  restrictions: { allergies: 'Hải sản', injuries: '', health_conditions: SECRET },
  ...overrides,
});
const PINNED_ENV = ['GEMINI_API_KEY', 'GEMINI_BASE_URL', 'GEMINI_TIMEOUT_MS'] as const;

describe('POST /api/v1/generate-plan (e2e, SDK thật + server Gemini giả)', () => {
  let app: INestApplication<App>;
  let fake: FakeGemini;
  const savedEnv: Partial<Record<(typeof PINNED_ENV)[number], string>> = {};

  beforeAll(async () => {
    fake = await startFakeGemini();
    for (const key of PINNED_ENV) savedEnv[key] = process.env[key];
    // Ghim trước khi nạp AppModule: máy dev có thể có khoá Gemini thật trong .env.
    process.env.GEMINI_API_KEY = 'test-key';
    process.env.GEMINI_BASE_URL = fake.url;
    process.env.GEMINI_TIMEOUT_MS = '200';

    const { AppModule } = await import('../src/app.module.js');
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication({ logger: false });
    configureApp(app);
    await app.init();
  });

  afterAll(async () => {
    await app.close();
    await fake.close();
    for (const key of PINNED_ENV) {
      if (savedEnv[key] === undefined) delete process.env[key];
      else process.env[key] = savedEnv[key];
    }
  });

  const post = (payload: object) => request(app.getHttpServer()).post('/api/v1/generate-plan').send(payload);

  it('returns a Gemini plan that follows the contract', async () => {
    fake.reply({ kind: 'json', body: SAMPLE_CONTENT });
    const res = await post(body()).expect(200);
    expect(res.body.source).toBe('gemini');
    expect(res.body.plan_id).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[0-9a-f]{4}-[0-9a-f]{12}$/);
    expect(res.body.days).toHaveLength(3);
    expect(res.body.daily_target).toMatchObject({ bmr: 1399, target_calories: 1624 });
    expect(res.body.grocery_list.map((group: { category: string }) => group.category)).toEqual([
      'protein',
      'produce',
      'pantry',
    ]);
    expect(fake.requests).toHaveLength(1);
  });

  it('sends the health text to Gemini but never returns it in the plan (#12)', async () => {
    fake.reply({ kind: 'json', body: SAMPLE_CONTENT });
    const res = await post(body()).expect(200);
    expect(fake.requests[0]).toContain(SECRET);
    expect(JSON.stringify(res.body)).not.toContain(SECRET);
  });

  it('retries once, then serves the sample when Gemini keeps breaking the contract', async () => {
    fake.reply({ kind: 'json', body: { days: [] } });
    const res = await post(body()).expect(200);
    expect(res.body.source).toBe('sample');
    expect(fake.requests).toHaveLength(2);
    expect(res.body.warnings.some((warning: string) => warning.startsWith('Đang dùng thực đơn mẫu'))).toBe(true);
  });

  it('serves the sample after one timed-out call, without retrying', async () => {
    fake.reply({ kind: 'hang' });
    const res = await post(body()).expect(200);
    expect(res.body.source).toBe('sample');
    expect(fake.requests).toHaveLength(1);
  });

  it.each([
    ['restrictions kiểu mảng cũ', { restrictions: { allergies: ['Hải sản'] } }],
    ['restrictions null', { restrictions: null }],
    ['ô nhập dài hơn 300 ký tự', { restrictions: { allergies: 'a'.repeat(301) } }],
    ['tuổi không phải số', { age: 'hai mươi' }],
    ['mục tiêu ngoài danh sách', { goal: 'lose_weight' }],
  ])('rejects %s with 400', async (_label, overrides) => {
    await post(body(overrides)).expect(400);
  });

  it('accepts a request without restrictions', async () => {
    fake.reply({ kind: 'json', body: SAMPLE_CONTENT });
    const res = await post(BASE).expect(200);
    expect(res.body.warnings).toEqual([]);
  });

  it('documents the response schema in Swagger', async () => {
    const res = await request(app.getHttpServer()).get('/docs-json').expect(200);
    expect(res.body.components.schemas).toHaveProperty('MealPlanResponseDto');
  });
});
```

Chạy:

```bash
cd backend_api && npm run test:e2e
```

Mong đợi: **FAIL** — `Cannot find module '../src/app.setup.js'`.

### Task 2 — `configureApp()`

`backend_api/src/app.setup.ts`:

```ts
import { type INestApplication, ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

// Dùng chung cho main.ts và test e2e, để test chạy đúng cấu hình của server thật.
export function configureApp(app: INestApplication): void {
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

  const config = new DocumentBuilder()
    .setTitle('SmartFit AI API')
    .setDescription('Backend API cho SmartFit AI — xem BRD.md ở repo gốc')
    .setVersion('1.0')
    .build();
  SwaggerModule.setup('docs', app, SwaggerModule.createDocument(app, config));
}
```

`backend_api/src/main.ts` (thay toàn bộ):

```ts
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module.js';
import { configureApp } from './app.setup.js';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  configureApp(app);
  await app.listen(process.env.PORT ?? 3000);
}
await bootstrap();
```

### Task 3 — Chạy lại, kiểm server thật

```bash
cd backend_api && npm run build && npm test && npm run test:e2e
(npm run start > /tmp/nest-phase2.log 2>&1 &); for i in $(seq 1 20); do curl -s localhost:3000/health >/dev/null && break; sleep 1; done
curl -s -o /dev/null -w '%{http_code}\n' -X POST localhost:3000/api/v1/generate-plan -H 'Content-Type: application/json' \
  -d '{"age":22,"gender":"female","height_cm":168,"weight_kg":62,"activity_level":"light","goal":"cut","restrictions":{"allergies":["Hải sản"]}}'
curl -s localhost:3000/docs-json | grep -o '"MealPlanResponseDto"' | head -1
pkill -f "nest start"
```

Mong đợi: build không lỗi; `Tests  61 passed (61)`; e2e `Tests  12 passed (12)`; `400`; `"MealPlanResponseDto"`.
