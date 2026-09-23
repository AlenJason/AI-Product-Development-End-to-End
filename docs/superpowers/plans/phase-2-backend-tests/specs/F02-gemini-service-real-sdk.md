# F02 — `GEMINI_BASE_URL`, server Gemini giả, test `GeminiService` với SDK thật

## Feature

`GeminiService` là chỗ duy nhất nói chuyện với Gemini nhưng chưa có test nào. Feature này:

1. Thêm biến tuỳ chọn `GEMINI_BASE_URL`: có giá trị thì SDK gửi request tới địa chỉ đó thay vì Google. Để trống (mặc định) thì hành vi y như cũ.
2. Viết `backend_api/test/fake-gemini-server.ts`: server HTTP cục bộ trả phản hồi đúng định dạng Gemini, đếm và lưu từng request, có các chế độ trả JSON / văn bản tuỳ ý / lỗi HTTP / không trả lời.
3. Test `GeminiService` với **SDK `@google/genai` thật** trỏ vào server giả: hết giờ, không tự gọi lại khi lỗi 500, khoá sai, văn bản không phải JSON, prompt và JSON mode được gửi đi.

Định dạng phản hồi và hành vi SDK dùng ở đây đã kiểm bằng SDK 2.24 thật trong brainstorm (F1–F4): `POST /v1beta/models/{model}:generateContent`; đọc `candidates[0].content.parts[].text`; hết giờ → `AbortError`; lỗi HTTP → `ApiError` có `status`; lỗi 500 → đúng 1 request.

## Scope

API-only:

- `backend_api/src/plan/gemini.service.ts` (sửa constructor)
- `backend_api/.env.example` (thêm `GEMINI_BASE_URL`)
- `backend_api/test/fake-gemini-server.ts` (mới)
- `backend_api/src/plan/gemini.service.spec.ts` (mới)

## Implementation

### API Routes

Không đổi route. `GEMINI_BASE_URL` để trống → `POST /api/v1/generate-plan` gọi Google như trước; latency không đổi (giới hạn cứng `GEMINI_TIMEOUT_MS` = 15 s/lần).

**Khoá API bên ngoài** (skill yêu cầu bước kiểm tra token): test dùng khoá giả `test-key` gửi tới server giả — không bao giờ cần khoá thật. Trường hợp khoá bị Google từ chối được giả bằng phản hồi 400 đúng định dạng Google → SDK ném `ApiError` 400 → `GeminiService` để lỗi đi tiếp cho `PlanService` xử lý (F03).

### UI Components

Không có.

### DB / KV Changes

Không có.

### Ràng buộc áp dụng

- **#3** khoá chỉ qua `ConfigService` — test truyền `ConfigService` giả, không đọc `.env`.
- **#12** lỗi JSON không trích nội dung Gemini — test gài một chuỗi bí mật vào phản hồi và kiểm thông báo lỗi.
- **#15** không để SDK tự gọi lại — test đếm số request thật khi server trả 500.
- **#4** ESM: import có đuôi `.js`.
- `GEMINI_BASE_URL` chỉ dùng cho test/dev; F06 ghi ràng buộc để production luôn để trống.

## Definition of Done

- [ ] `GEMINI_BASE_URL` trống → client tạo như cũ; có giá trị → request tới đúng địa chỉ đó
- [ ] 6 test trong `gemini.service.spec.ts` pass, chạy dưới 2 giây (test hết giờ dùng timeout 200 ms)
- [ ] Test lỗi 500 xác nhận đúng **1** request
- [ ] `npm run build` không lỗi; `npm test` xanh (9 file)
- [x] All API routes complete within deployment timeout — không đổi route
- [x] Auth check at top of each protected handler — không áp dụng

## Test Checklist

1. **@happy**: server trả JSON hợp lệ → nhận đúng object; request chứa khối `<du_lieu_nguoi_dung>` và `"responseMimeType":"application/json"`
2. **@auth**: không áp dụng (không có đăng nhập người dùng ở giai đoạn này)
3. **@timeout**: server không trả lời → `GeminiTimeoutError` sau ~200 ms
4. **@partial-fail**: 500 → `ApiError` 500 và đúng 1 request; văn bản không phải JSON → lỗi chung, không chứa nội dung
5. **@token**: 400 "API key not valid" → `ApiError` 400 được ném tiếp
6. **@db**: không áp dụng

## Tasks

### Task 1 — Viết test trước

`backend_api/src/plan/gemini.service.spec.ts`:

```ts
import type { ConfigService } from '@nestjs/config';
import { startFakeGemini, type FakeGemini } from '../../test/fake-gemini-server.js';
import { CreatePlanDto } from './dto/create-plan.dto.js';
import { RestrictionsDto } from './dto/restrictions.dto.js';
import { ActivityLevel } from './enums/activity-level.enum.js';
import { Gender } from './enums/gender.enum.js';
import { Goal } from './enums/goal.enum.js';
import { GeminiService, GeminiTimeoutError } from './gemini.service.js';

const target = { bmi: 22, bmr: 1399, tdee: 1924, target_calories: 1624, protein_g: 102, carbs_g: 183, fat_g: 54 };
const SECRET = 'BENH-NEN-BI-MAT-123';

function profile(): CreatePlanDto {
  return Object.assign(new CreatePlanDto(), {
    age: 22,
    gender: Gender.FEMALE,
    height_cm: 168,
    weight_kg: 62,
    activity_level: ActivityLevel.LIGHT,
    goal: Goal.CUT,
    restrictions: Object.assign(new RestrictionsDto(), { health_conditions: SECRET }),
  });
}

function service(env: Record<string, string>): GeminiService {
  return new GeminiService({ get: (key: string) => env[key] } as unknown as ConfigService);
}

describe('GeminiService — SDK thật, server Gemini giả', () => {
  let fake: FakeGemini;
  let gemini: GeminiService;

  beforeAll(async () => {
    fake = await startFakeGemini();
    gemini = service({ GEMINI_API_KEY: 'test-key', GEMINI_BASE_URL: fake.url, GEMINI_TIMEOUT_MS: '200' });
  });

  afterAll(() => fake.close());

  it('is not configured without an API key', () => {
    expect(service({}).isConfigured).toBe(false);
  });

  it('returns the parsed JSON and sends the prompt in JSON mode', async () => {
    fake.reply({ kind: 'json', body: { days: [] } });
    await expect(gemini.generatePlanContent(profile(), target)).resolves.toEqual({ days: [] });
    expect(fake.requests).toHaveLength(1);
    expect(fake.requests[0]).toContain('du_lieu_nguoi_dung');
    expect(fake.requests[0]).toContain('"responseMimeType":"application/json"');
  });

  it('turns a timeout into GeminiTimeoutError', async () => {
    fake.reply({ kind: 'hang' });
    await expect(gemini.generatePlanContent(profile(), target)).rejects.toBeInstanceOf(GeminiTimeoutError);
  });

  it('sends exactly one request on HTTP 500 — the SDK must not retry on its own (#15)', async () => {
    fake.reply({ kind: 'error', status: 500, message: 'boom' });
    await expect(gemini.generatePlanContent(profile(), target)).rejects.toMatchObject({
      name: 'ApiError',
      status: 500,
    });
    expect(fake.requests).toHaveLength(1);
  });

  it('passes a rejected API key through as ApiError 400', async () => {
    fake.reply({ kind: 'error', status: 400, message: 'API key not valid. Please pass a valid API key.' });
    await expect(gemini.generatePlanContent(profile(), target)).rejects.toMatchObject({ status: 400 });
  });

  it('never echoes Gemini output in the error when the text is not JSON (#12)', async () => {
    fake.reply({ kind: 'text', text: `không phải JSON ${SECRET}` });
    const error = await gemini.generatePlanContent(profile(), target).catch((e: unknown) => e);
    expect(error).toBeInstanceOf(Error);
    expect((error as Error).message).toBe('Gemini trả về chuỗi không phải JSON hợp lệ');
  });
});
```

Chạy:

```bash
cd backend_api && npx vitest run src/plan/gemini.service.spec.ts
```

Mong đợi: **FAIL** — `Cannot find module '../../test/fake-gemini-server.js'`. Test đỏ vì thiếu server giả, **chưa có request nào ra ngoài**.

> Thứ tự các task là cố ý: nếu tạo server giả trước khi có điểm nối `GEMINI_BASE_URL` rồi chạy test, SDK sẽ gửi prompt (có chuỗi sức khoẻ giả) tới Google thật bằng khoá giả. Luôn làm Task 2 trước Task 3.

### Task 2 — Điểm nối `GEMINI_BASE_URL`

`backend_api/src/plan/gemini.service.ts` — trong constructor, thay dòng:

```ts
    this.client = apiKey ? new GoogleGenAI({ apiKey }) : null;
```

bằng:

```ts
    // Chỉ để trỏ SDK sang server Gemini giả khi test; production để trống.
    const baseUrl = this.config.get<string>('GEMINI_BASE_URL');
    this.client = apiKey ? new GoogleGenAI({ apiKey, ...(baseUrl ? { httpOptions: { baseUrl } } : {}) }) : null;
```

`backend_api/.env.example` — thêm vào cuối:

```
# Chỉ dùng khi test với server Gemini giả. Để trống = gọi Google thật.
GEMINI_BASE_URL=
```

### Task 3 — Server Gemini giả

`backend_api/test/fake-gemini-server.ts`:

```ts
import { createServer } from 'node:http';
import type { AddressInfo } from 'node:net';

// Server Gemini giả cho test: SDK @google/genai thật gửi request tới đây qua GEMINI_BASE_URL.
export type FakeGeminiReply =
  | { kind: 'json'; body: unknown }
  | { kind: 'text'; text: string }
  | { kind: 'error'; status: number; message: string }
  | { kind: 'hang' };

export interface FakeGemini {
  url: string;
  requests: string[];
  // Đặt hàng đợi phản hồi và xoá lịch sử request. Hết hàng đợi thì lặp lại phản hồi cuối.
  reply(...replies: FakeGeminiReply[]): void;
  close(): Promise<void>;
}

export async function startFakeGemini(): Promise<FakeGemini> {
  let queue: FakeGeminiReply[] = [{ kind: 'error', status: 500, message: 'Chưa đặt phản hồi cho server giả' }];
  const requests: string[] = [];

  const server = createServer((req, res) => {
    let body = '';
    req.on('data', (chunk: Buffer) => (body += chunk.toString()));
    req.on('end', () => {
      requests.push(body);
      const next = queue.length > 1 ? (queue.shift() as FakeGeminiReply) : queue[0];
      if (next.kind === 'hang') return;
      if (next.kind === 'error') {
        res.writeHead(next.status, { 'content-type': 'application/json' });
        res.end(JSON.stringify({ error: { code: next.status, message: next.message, status: 'ERROR' } }));
        return;
      }
      const text = next.kind === 'json' ? JSON.stringify(next.body) : next.text;
      res.writeHead(200, { 'content-type': 'application/json' });
      res.end(JSON.stringify({ candidates: [{ content: { role: 'model', parts: [{ text }] }, finishReason: 'STOP' }] }));
    });
  });

  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address() as AddressInfo;

  return {
    url: `http://127.0.0.1:${port}`,
    requests,
    reply: (...replies) => {
      queue = replies;
      requests.length = 0;
    },
    close: () =>
      new Promise<void>((resolve) => {
        server.closeAllConnections();
        server.close(() => resolve());
      }),
  };
}
```

### Task 4 — Chạy lại

```bash
cd backend_api && npx vitest run src/plan/gemini.service.spec.ts
cd backend_api && npm run build && npm test
```

Mong đợi: `Tests  6 passed (6)`; build không lỗi; `Test Files  9 passed (9)`.
