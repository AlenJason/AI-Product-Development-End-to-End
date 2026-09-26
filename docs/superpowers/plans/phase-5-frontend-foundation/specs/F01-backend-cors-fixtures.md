# F01 — Backend: CORS và fixture hợp đồng cho Flutter (PLAN 5.7, 5.8)

## Feature

Hai việc phía backend để app Flutter nối vào được và nối đúng:

1. **CORS (5.7, quyết định Q2).** Bản web của app (`flutter run -d chrome`) chạy ở origin khác backend, nên trình duyệt chặn mọi request nếu backend không trả header CORS. `resolveCorsOptions()` đọc `CORS_ORIGINS`:

   | `CORS_ORIGINS` | `NODE_ENV` | Kết quả |
   |---|---|---|
   | danh sách `http(s)://host[:port]`, cách nhau dấu phẩy | bất kỳ | chỉ các origin đó |
   | trống | khác `production` | `http://localhost` và `http://127.0.0.1`, mọi cổng (Flutter web chạy cổng ngẫu nhiên) |
   | trống | `production` | tắt CORS — chỉ app mobile gọi được |
   | có origin sai dạng (có đường dẫn, thiếu `http(s)://`) | bất kỳ | ném lỗi, backend không khởi động |

   Cho phép `GET`, `POST`, `DELETE`; header `Content-Type`, `Authorization`; `credentials: false` (đăng nhập bằng header, không có cookie); `maxAge: 600`. App mobile không gửi `Origin` nên không bị ảnh hưởng.

2. **Fixture hợp đồng (5.8, mới — quyết định Q1).** `test/contract-fixtures.e2e-spec.ts` gọi thật 14 tình huống qua HTTP và so response với file JSON đã commit trong `frontend_app/test/fixtures/`. Giá trị đổi theo mỗi lần chạy được thay bằng giá trị cố định: UUID → `00000000-0000-4000-8000-00000000000N` (cùng UUID → cùng giá trị ở mọi file), `access_token`, `created_at`. `RandomSource` được ghi đè bằng `{ next: () => 0 }` để đổi món/đổi bài luôn ra cùng kết quả. Hợp đồng đổi mà fixture chưa xuất lại → test đỏ; xuất lại bằng `npm run fixtures:update` (chạy đúng file test đó với `UPDATE_FIXTURES=1`). App Flutter dùng cùng các file này cho test vòng tròn (F03), ApiClient (F04), provider (F05).

   | Fixture | Request |
   |---|---|
   | `profile` | hồ sơ gửi đi (nữ 22 tuổi, 168 cm, 62 kg, vận động nhẹ, giảm cân; dị ứng "Hải sản", chấn thương "Đau gối", bệnh "Tiểu đường") |
   | `health` | `GET /health` |
   | `auth_login` | `POST /api/v1/auth/google` với `mock:<email>` |
   | `generate_plan` | `POST /api/v1/generate-plan` (đã đăng nhập) |
   | `history` | `GET /api/v1/plans/history` |
   | `meals_swap`, `exercises_swap` | đổi `m1_2`, `e1_2` |
   | `feedback`, `feedback_danger` | ngày 1: nặng + đau mỏi + ăn đúng; nhẹ + dấu hiệu nguy hiểm |
   | `error_400` … `error_422` | tuổi là chữ; thiếu token; plan không có; hồ sơ đổi mục tiêu; không còn động tác nhẹ hơn (`e3_2`) |

## Scope

API + test + CI:

- `backend_api/src/cors-options.ts`, `cors-options.spec.ts` (mới)
- `backend_api/src/app.setup.ts` (sửa)
- `backend_api/test/test-app.ts` (sửa), `cors.e2e-spec.ts`, `contract-fixtures.e2e-spec.ts` (mới)
- `backend_api/package.json` (script `fixtures:update`), `backend_api/.env.example`
- `frontend_app/test/fixtures/*.json` (14 file, sinh bằng lệnh — không viết tay)
- `.github/workflows/backend.yml` (thêm đường dẫn fixture)

## Implementation

### API Routes

Không thêm route. CORS áp cho mọi route qua `configureApp()` (#18).

**Độ trễ:** preflight `OPTIONS` trả 204 ngay trong middleware (< 5 ms). Đo trong Chrome thật khi lập plan: `generate-plan` chế độ giả lập 27 ms kể cả preflight.

**Khoá API bên ngoài:** không có. Test fixture chạy ở chế độ giả lập (`createTestApp()` ghim `AUTH_MODE=mock`, không có khoá Gemini — #17).

### UI Components

Không có.

### DB / KV Changes

Không có. Test fixture dùng SQLite trong RAM như mọi e2e.

### Ràng buộc áp dụng

- **#12** fixture chỉ chứa hồ sơ giả; `warnings` không nhắc lại chữ người dùng (đã có test ở giai đoạn 4).
- **#17** fixture sinh bằng `createTestApp()`: DB trong RAM, đăng nhập giả lập, không gọi Gemini; `createTestApp()` ghim thêm `CORS_ORIGINS=''` để `.env` của máy dev không đổi kết quả e2e.
- **#18** CORS nằm trong `configureApp()`, không thêm vào `main.ts`.
- **#20** CORS có trong bản build: `npm run build && npm run test:smoke` vẫn xanh.
- Ràng buộc mới #26 (fixture hợp đồng) và #27 (CORS) ghi vào wiki ở F07.

## Definition of Done

- [ ] `npm run fixtures:update` sinh đúng 14 file trong `frontend_app/test/fixtures/`; chạy lại lần hai không đổi file nào (`git status` sạch)
- [ ] `npm test` → `Test Files  26 passed (26)`, `Tests  264 passed (264)`
- [ ] `npm run test:e2e` → `Test Files  7 passed (7)`, `Tests  66 passed (66)`
- [ ] Sửa tay một fixture → `npm run test:e2e` đỏ, thông báo "… đã cũ — chạy npm run fixtures:update"
- [ ] `npm run typecheck`, `npm run build`, `npm run test:smoke`, `npm run lint` sạch
- [ ] Không route nào đổi hành vi với request không có `Origin` (app mobile)

## Test Checklist

1. **@happy**: preflight từ `http://localhost:5000` xin `POST` + `Authorization` → 204, có `Access-Control-Allow-Origin` đúng origin và `Access-Control-Allow-Headers` chứa `Authorization` (`cors.e2e-spec.ts`)
2. **@auth**: origin lạ (`https://evil.example`) → không có `Access-Control-Allow-Origin`; request không có `Origin` → không có header CORS nào
3. **@config**: `CORS_ORIGINS=https://smartfit.example` → chỉ origin đó; `NODE_ENV=production` + trống → không header; `CORS_ORIGINS=*` → `createTestApp()` ném lỗi (backend không lên); unit test kiểm thêm origin có đường dẫn
4. **@contract**: 14 fixture khớp response thật; hợp đồng đổi → đỏ
5. **@timeout**: không có route mới; preflight không chạm service
6. **@partial-fail**: không áp dụng
7. **@token**: fixture `error_401` là response thật khi thiếu token
8. **@db**: không đổi schema

## Tasks

### Task 1 — `resolveCorsOptions()` và unit test

`backend_api/src/cors-options.ts`:

```ts
import type { CorsOptions } from '@nestjs/common/interfaces/external/cors-options.interface.js';

// Khi phát triển, Flutter web chạy ở cổng ngẫu nhiên trên localhost (`flutter run -d chrome`).
const DEV_ORIGINS = [/^http:\/\/localhost(:\d+)?$/, /^http:\/\/127\.0\.0\.1(:\d+)?$/];

// CORS chỉ cần cho bản web của app — trình duyệt chặn request khác origin nếu backend không cho phép.
// App mobile không gửi Origin nên không bị ảnh hưởng. Không dùng cookie (đăng nhập bằng header Authorization),
// nên credentials: false. Sai cấu hình → ném lỗi, backend không khởi động.
export function resolveCorsOptions(env: (key: string) => string | undefined): CorsOptions | null {
  const listed = (env('CORS_ORIGINS') ?? '')
    .split(',')
    .map((origin) => origin.trim().replace(/\/+$/, ''))
    .filter(Boolean);
  for (const origin of listed) {
    if (!/^https?:\/\/[^/\s]+$/.test(origin)) {
      throw new Error(`CORS_ORIGINS: "${origin}" phải có dạng http(s)://host[:port], không có đường dẫn.`);
    }
  }
  // Deploy mà không khai báo origin → tắt CORS, chỉ app mobile gọi được.
  if (listed.length === 0 && env('NODE_ENV')?.trim() === 'production') return null;
  return {
    origin: listed.length > 0 ? listed : DEV_ORIGINS,
    methods: ['GET', 'POST', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: false,
    maxAge: 600,
  };
}
```

`backend_api/src/cors-options.spec.ts`:

```ts
import { resolveCorsOptions } from './cors-options.js';

const resolve = (env: Record<string, string>) => resolveCorsOptions((key) => env[key]);
const allows = (origins: unknown, origin: string) =>
  (origins as (string | RegExp)[]).some((allowed) => (typeof allowed === 'string' ? allowed === origin : allowed.test(origin)));

describe('resolveCorsOptions', () => {
  it('allows localhost and 127.0.0.1 on any port during development', () => {
    const options = resolve({});
    for (const origin of ['http://localhost', 'http://localhost:5000', 'http://127.0.0.1:61234']) {
      expect(allows(options?.origin, origin)).toBe(true);
    }
    for (const origin of ['http://localhost.evil.com', 'https://evil.example', 'http://192.168.1.10:5000']) {
      expect(allows(options?.origin, origin)).toBe(false);
    }
  });

  it('only allows the listed origins when CORS_ORIGINS is set', () => {
    const options = resolve({ CORS_ORIGINS: ' https://smartfit.example/ , http://192.168.1.10:5000 ' });
    expect(options?.origin).toEqual(['https://smartfit.example', 'http://192.168.1.10:5000']);
  });

  it('turns CORS off in production when no origin is listed (mobile apps send no Origin)', () => {
    expect(resolve({ NODE_ENV: 'production' })).toBeNull();
    expect(resolve({ NODE_ENV: 'production', CORS_ORIGINS: 'https://smartfit.example' })?.origin).toEqual([
      'https://smartfit.example',
    ]);
  });

  it('allows the Authorization header without cookies', () => {
    expect(resolve({})).toMatchObject({ allowedHeaders: ['Content-Type', 'Authorization'], credentials: false });
  });

  it.each(['*', 'smartfit.example', 'https://smartfit.example/app'])('refuses to start with CORS_ORIGINS=%s', (value) => {
    expect(() => resolve({ CORS_ORIGINS: value })).toThrow(/CORS_ORIGINS/);
  });
});
```

```bash
cd backend_api && npx vitest run src/cors-options.spec.ts   # Tests  7 passed (7)
```

### Task 2 — Bật CORS trong `configureApp()`

`backend_api/src/app.setup.ts` (biến `DocumentBuilder` đổi tên thành `document` vì `config` giờ là `ConfigService`):

```ts
import { type INestApplication, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { resolveCorsOptions } from './cors-options.js';

// Dùng chung cho main.ts và test e2e, để test chạy đúng cấu hình của server thật.
export function configureApp(app: INestApplication): void {
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

  const config = app.get(ConfigService);
  const cors = resolveCorsOptions((key) => config.get<string>(key));
  if (cors) app.enableCors(cors);

  const document = new DocumentBuilder()
    .setTitle('SmartFit AI API')
    .setDescription('Backend API cho SmartFit AI — xem BRD.md ở repo gốc')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  SwaggerModule.setup('docs', app, SwaggerModule.createDocument(app, document));
}
```

### Task 3 — `createTestApp()` nhận hàm ghi đè provider, ghim `CORS_ORIGINS`

`backend_api/test/test-app.ts`:

```ts
import type { INestApplication } from '@nestjs/common';
import { Test, type TestingModuleBuilder } from '@nestjs/testing';
import request from 'supertest';
import { configureApp } from '../src/app.setup.js';

export interface TestApp {
  app: INestApplication;
  close: () => Promise<void>;
}

// Máy dev có thể có khoá Gemini thật, file DB thật, AUTH_MODE=google trong .env (#17):
// ghim env trước khi nạp AppModule (ConfigModule.forRoot đọc .env ngay lúc import), trả lại khi đóng.
// Mặc định: DB trong RAM, đăng nhập giả lập, không có Gemini.
// `configure` ghi đè provider khi cần kết quả tất định (ví dụ RandomSource khi xuất fixture hợp đồng).
export async function createTestApp(
  env: Record<string, string> = {},
  configure: (builder: TestingModuleBuilder) => TestingModuleBuilder = (builder) => builder,
): Promise<TestApp> {
  const pinned: Record<string, string> = {
    DATABASE_PATH: ':memory:',
    AUTH_MODE: 'mock',
    GOOGLE_CLIENT_ID: '',
    JWT_SECRET: '',
    JWT_EXPIRES_IN: '',
    ALLOW_MOCK_AUTH: '',
    GEMINI_API_KEY: '',
    GEMINI_BASE_URL: '',
    GEMINI_THINKING: '',
    GEMINI_TOTAL_TIMEOUT_MS: '',
    CORS_ORIGINS: '',
    ...env,
  };
  const saved = Object.fromEntries(Object.keys(pinned).map((key) => [key, process.env[key]]));
  const restore = () => {
    for (const [key, value] of Object.entries(saved)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  };
  Object.assign(process.env, pinned);

  try {
    const { AppModule } = await import('../src/app.module.js');
    const moduleRef = await configure(Test.createTestingModule({ imports: [AppModule] })).compile();
    const app = moduleRef.createNestApplication({ logger: false });
    configureApp(app);
    await app.init();
    return {
      app,
      close: async () => {
        await app.close();
        restore();
      },
    };
  } catch (error) {
    restore();
    throw error;
  }
}

export interface LoginBody {
  access_token: string;
  user: { id: string; email: string; name: string };
}

// Đăng nhập giả lập (AUTH_MODE=mock): id_token là "mock:<email>".
export async function loginMock(testApp: TestApp, email: string): Promise<LoginBody> {
  const res = await request(testApp.app.getHttpServer())
    .post('/api/v1/auth/google')
    .send({ id_token: `mock:${email}` })
    .expect(200);
  return res.body as LoginBody;
}
```

### Task 4 — E2E CORS

`backend_api/test/cors.e2e-spec.ts`:

```ts
import request from 'supertest';
import { createTestApp, type TestApp } from './test-app.js';

// Trình duyệt gửi preflight OPTIONS trước mọi POST JSON hay request có Authorization từ origin khác (Flutter web).
const preflight = (testApp: TestApp, origin: string) =>
  request(testApp.app.getHttpServer())
    .options('/api/v1/generate-plan')
    .set('Origin', origin)
    .set('Access-Control-Request-Method', 'POST')
    .set('Access-Control-Request-Headers', 'content-type,authorization');

describe('CORS cho Flutter web (e2e)', () => {
  describe('khi phát triển (CORS_ORIGINS để trống)', () => {
    let testApp: TestApp;

    beforeAll(async () => {
      testApp = await createTestApp();
    });

    afterAll(async () => {
      await testApp.close();
    });

    it('answers the preflight from Flutter web on localhost', async () => {
      const res = await preflight(testApp, 'http://localhost:5000').expect(204);
      expect(res.headers['access-control-allow-origin']).toBe('http://localhost:5000');
      expect(res.headers['access-control-allow-headers']).toContain('Authorization');
      expect(res.headers['access-control-allow-methods']).toContain('POST');
    });

    it('does not allow another origin', async () => {
      const res = await preflight(testApp, 'https://evil.example');
      expect(res.headers['access-control-allow-origin']).toBeUndefined();
    });

    it('does not change requests without Origin (mobile apps, curl)', async () => {
      const res = await request(testApp.app.getHttpServer()).get('/health').expect(200);
      expect(res.headers['access-control-allow-origin']).toBeUndefined();
    });
  });

  it('only allows the configured origins', async () => {
    const testApp = await createTestApp({ CORS_ORIGINS: 'https://smartfit.example' });
    try {
      expect((await preflight(testApp, 'https://smartfit.example').expect(204)).headers['access-control-allow-origin']).toBe(
        'https://smartfit.example',
      );
      expect((await preflight(testApp, 'http://localhost:5000')).headers['access-control-allow-origin']).toBeUndefined();
    } finally {
      await testApp.close();
    }
  });

  it('is off in production when no origin is configured', async () => {
    const testApp = await createTestApp({ NODE_ENV: 'production', ALLOW_MOCK_AUTH: 'true' });
    try {
      expect((await preflight(testApp, 'http://localhost:5000')).headers['access-control-allow-origin']).toBeUndefined();
    } finally {
      await testApp.close();
    }
  });

  it('refuses to start with an invalid CORS_ORIGINS', async () => {
    await expect(createTestApp({ CORS_ORIGINS: '*' })).rejects.toThrow(/CORS_ORIGINS/);
  });
});
```

### Task 5 — Fixture hợp đồng

`backend_api/test/contract-fixtures.e2e-spec.ts`:

```ts
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import request from 'supertest';
import { RandomSource } from '../src/plan/adjust/random-source.js';
import { createTestApp, loginMock, type TestApp } from './test-app.js';

// Fixture hợp đồng cho app Flutter (frontend_app/test/fixtures/): JSON thật backend trả qua HTTP, đã thay các giá trị
// đổi theo mỗi lần chạy (UUID, token, thời điểm) bằng giá trị cố định. Test này đỏ khi hợp đồng đổi mà fixture chưa
// xuất lại — chạy `npm run fixtures:update` rồi commit cả fixture lẫn phần sửa model Dart.
const FIXTURES_DIR = new URL('../../frontend_app/test/fixtures/', import.meta.url);
const UPDATE = process.env.UPDATE_FIXTURES === '1';
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const FIXED_TIME = '2026-09-24T00:00:00.000Z';
const FIXED_TOKEN = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.fixture.signature';

const PROFILE = {
  age: 22,
  gender: 'female',
  height_cm: 168,
  weight_kg: 62,
  activity_level: 'light',
  goal: 'cut',
  restrictions: { allergies: 'Hải sản', injuries: 'Đau gối', health_conditions: 'Tiểu đường' },
};

describe('Fixture hợp đồng cho Flutter (e2e)', () => {
  let testApp: TestApp;
  const fixedIds = new Map<string, string>();
  const http = () => request(testApp.app.getHttpServer());

  // UUID giống nhau ở mọi file (plan_id trong lịch sử = plan_id lúc tạo) → cùng một giá trị cố định.
  const normalize = (value: unknown, key?: string): unknown => {
    if (Array.isArray(value)) return value.map((item) => normalize(item));
    if (value && typeof value === 'object') {
      return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, normalize(v, k)]));
    }
    if (typeof value !== 'string') return value;
    if (key === 'access_token') return FIXED_TOKEN;
    if (key === 'created_at') return FIXED_TIME;
    if (UUID.test(value)) {
      if (!fixedIds.has(value)) fixedIds.set(value, `00000000-0000-4000-8000-${String(fixedIds.size + 1).padStart(12, '0')}`);
      return fixedIds.get(value);
    }
    return value;
  };

  const check = (name: string, body: unknown) => {
    const file = new URL(`${name}.json`, FIXTURES_DIR);
    const actual = normalize(body);
    if (UPDATE) {
      mkdirSync(FIXTURES_DIR, { recursive: true });
      writeFileSync(file, `${JSON.stringify(actual, null, 2)}\n`);
      return;
    }
    expect(actual, `${name}.json đã cũ — chạy npm run fixtures:update`).toEqual(JSON.parse(readFileSync(file, 'utf-8')));
  };

  beforeAll(async () => {
    testApp = await createTestApp({}, (builder) => builder.overrideProvider(RandomSource).useValue({ next: () => 0 }));
  });

  afterAll(async () => {
    await testApp.close();
  });

  it('matches every committed fixture', async () => {
    check('profile', PROFILE);
    check('health', (await http().get('/health').expect(200)).body);

    const login = await loginMock(testApp, 'sv@vku.edu.vn');
    check('auth_login', login);
    const auth = `Bearer ${login.access_token}`;

    const plan = (await http().post('/api/v1/generate-plan').set('Authorization', auth).send(PROFILE).expect(200)).body;
    check('generate_plan', plan);
    check('history', (await http().get('/api/v1/plans/history').set('Authorization', auth).expect(200)).body);
    check('meals_swap', (await http().post('/api/v1/meals/swap').send({ profile: PROFILE, plan, meal_id: 'm1_2' }).expect(200)).body);
    check('exercises_swap', (await http().post('/api/v1/exercises/swap').send({ profile: PROFILE, plan, exercise_id: 'e1_2' }).expect(200)).body);
    const feedback = { profile: PROFILE, plan, day_number: 1, eating: 'on_plan' };
    check('feedback', (await http().post('/api/v1/feedback').send({ ...feedback, intensity: 'hard', body_states: ['sore'] }).expect(200)).body);
    check('feedback_danger', (await http().post('/api/v1/feedback').send({ ...feedback, intensity: 'easy', body_states: ['danger_sign'] }).expect(200)).body);

    check('error_400', (await http().post('/api/v1/generate-plan').send({ ...PROFILE, age: 'hai mươi' }).expect(400)).body);
    check('error_401', (await http().get('/api/v1/plans/history').expect(401)).body);
    check('error_404', (await http().get('/api/v1/plans/history/00000000-0000-4000-8000-00000000abcd').set('Authorization', auth).expect(404)).body);
    check('error_409', (await http().post('/api/v1/meals/swap').send({ profile: { ...PROFILE, goal: 'bulk' }, plan, meal_id: 'm1_1' }).expect(409)).body);
    check('error_422', (await http().post('/api/v1/exercises/swap').send({ profile: PROFILE, plan, exercise_id: 'e3_2' }).expect(422)).body);
  });
});
```

`backend_api/package.json`, thêm vào `scripts` ngay sau `test:e2e`:

```json
    "fixtures:update": "UPDATE_FIXTURES=1 vitest run --config ./vitest.config.e2e.ts test/contract-fixtures.e2e-spec.ts",
```

Sinh fixture (không viết tay):

```bash
cd backend_api
npm run fixtures:update     # Tests  1 passed (1) — ghi 14 file vào ../frontend_app/test/fixtures/
npm run fixtures:update     # lần hai: git status không đổi (kết quả tất định)
ls ../frontend_app/test/fixtures | wc -l   # 14
```

### Task 6 — `.env.example` và CI backend

`backend_api/.env.example`, ngay sau `PORT=3000`:

```bash
# Origin được gọi API từ trình duyệt (bản web của app), cách nhau dấu phẩy, ví dụ https://smartfit.example.com.
# Để trống: khi phát triển cho mọi cổng của http://localhost và http://127.0.0.1 (flutter run -d chrome);
# khi NODE_ENV=production thì tắt CORS — chỉ app mobile gọi được. App mobile không cần CORS.
CORS_ORIGINS=
```

`.github/workflows/backend.yml`, trong **cả hai** khối `paths` (`push` và `pull_request`), ngay trước dòng `'.github/workflows/backend.yml'` — sửa fixture phải chạy lại test so fixture:

```yaml
      - 'ai_workspace/**'
      # test/contract-fixtures.e2e-spec.ts so fixture đã commit với response thật của backend
      - 'frontend_app/test/fixtures/**'
      - '.github/workflows/backend.yml'
```

### Task 7 — Cổng kiểm tra F01

```bash
cd backend_api
npm run typecheck
npm run build
npm test            # Test Files  26 passed (26) · Tests  264 passed (264)
npm run test:e2e    # Test Files  7 passed (7) · Tests  66 passed (66)
npm run test:smoke
npm run lint
```
