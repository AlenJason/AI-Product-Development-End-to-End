# F01 — Cơ sở dữ liệu: TypeORM + SQLite, entity, migration

## Feature

Thêm tầng lưu trữ cho tài khoản và lịch sử (BRD mục 4, FR-6, FR-7): TypeORM 1.x + driver `better-sqlite3@12`, hai entity `User` và `PlanRecord`, một migration tạo bảng chạy tự động lúc khởi động (quyết định Q1, Q2). Không có endpoint mới — F02, F03 dùng tầng này.

Cùng lúc, e2e chuyển sang dùng chung một hàm `createTestApp()`. Từ F01, `AppModule` mở file DB lúc khởi động; nếu test không ghim `DATABASE_PATH=:memory:`, chạy `npm run test:e2e` sẽ tạo `backend_api/database.sqlite` thật trên máy dev.

Những điều đã kiểm chứng khi lập plan (bản sao `backend_api/` trong thư mục nháp, không đụng repo):

- `better-sqlite3@12` cài và chạy được trên Node 26 (có bản dựng sẵn cho Node 20–26). **Không** cài bản 13: TypeORM 1.1.1 chỉ nhận `^12`.
- Migration viết bằng API `Table` khớp entity **từng cột** (schema diff của TypeORM rỗng) chỉ khi: `users.id` là `varchar` không ghi độ dài, `created_at` mặc định `datetime('now')` (không phải `CURRENT_TIMESTAMP`). Bản đầu tiên lệch ở đúng hai chỗ này — test `migrations.spec.ts` khoá lại.
- Giá trị mặc định `datetime('now')` của SQLite chỉ chính xác tới **giây**: hai plan tạo trong cùng một giây có cùng `created_at` và thứ tự lịch sử không xác định. Vì vậy `plan_records.created_at` là cột thường, code tự gán `new Date()` (TypeORM lưu tới mili-giây, UTC).
- **Hai entity import lẫn nhau phải khai báo quan hệ bằng `Relation<...>`.** Nếu không, bản build ESM gọi `__metadata("design:type", User)` khi `User` chưa khởi tạo → `ReferenceError: Cannot access 'User' before initialization` và server không lên. **Vitest không bắt được lỗi này** (mọi test đều xanh); chỉ chạy `node dist/main.js` mới thấy. F04 thêm smoke test cho đúng loại lỗi này.
- Khoá ngoại được bật (`PRAGMA foreign_keys` = 1), nên xoá user thì `ON DELETE CASCADE` xoá luôn plan của họ.

## Scope

API (hạ tầng):

- `backend_api/package.json`, `backend_api/package-lock.json` — thêm `typeorm`, `@nestjs/typeorm`, `better-sqlite3@12`, duyệt install script
- `backend_api/src/database/entities/user.entity.ts` (mới)
- `backend_api/src/database/entities/plan-record.entity.ts` (mới)
- `backend_api/src/database/migrations/1790208000000-initial-schema.ts` (mới)
- `backend_api/src/database/data-source-options.ts` (mới)
- `backend_api/src/database/database.module.ts` (mới)
- `backend_api/src/database/migrations.spec.ts` (mới)
- `backend_api/test/memory-data-source.ts` (mới)
- `backend_api/test/test-app.ts` (mới)
- `backend_api/src/app.module.ts`, `backend_api/test/app.e2e-spec.ts`, `backend_api/test/generate-plan.e2e-spec.ts`
- `backend_api/.gitignore`, `backend_api/.env.example`

## Implementation

### API Routes

Không thêm route. Lúc khởi động, backend mở file DB và chạy migration còn thiếu (lần đầu tạo 2 bảng, các lần sau chỉ đọc bảng `migrations`): vài mili-giây, không ảnh hưởng thời gian phản hồi.

### UI Components

Không có.

### DB / KV Changes

Bảng `users`:

| Cột | Kiểu | Ghi chú |
|---|---|---|
| `id` | `varchar` PK | UUID do TypeORM sinh |
| `google_sub` | `varchar(255)` UNIQUE | `sub` của Google; chế độ mock: `mock:<email>` |
| `email` | `varchar(320)` | chữ thường |
| `name` | `varchar(200)` | |
| `created_at` | `datetime` mặc định `datetime('now')` | |

Bảng `plan_records`:

| Cột | Kiểu | Ghi chú |
|---|---|---|
| `id` | `varchar(36)` PK | chính là `plan_id` (#16) |
| `user_id` | `varchar` FK → `users.id` `ON DELETE CASCADE` | |
| `target_calories` | `integer` | để trả danh sách mà không đọc JSON |
| `plan_json` | `text` (`simple-json`) | đúng response đã trả, **không có `restrictions`** (#12) |
| `created_at` | `datetime` | code tự gán, chính xác tới mili-giây |

Chỉ mục `(user_id, created_at)` cho truy vấn lịch sử.

**Migration:** `InitialSchema1790208000000`, chạy tự động nhờ `migrationsRun: true`; không cần lệnh CLI. `synchronize` luôn `false`. Đổi entity về sau: viết migration mới trong `src/database/migrations/`, thêm vào mảng `migrations` của `dataSourceOptions()`. `migrations.spec.ts` đỏ và in ra đúng câu SQL còn thiếu nếu quên.

Chỉ dùng kiểu cột có ở cả SQLite lẫn Postgres. Ngoại lệ duy nhất là biểu thức mặc định `datetime('now')`. Nếu chuyển sang Postgres (#11), viết một migration khởi tạo mới cho Postgres.

### Ràng buộc áp dụng

- **#4** ESM: import tương đối có đuôi `.js`; quan hệ entity dùng `Relation<>` (phát hiện mới, ghi vào wiki ở F05).
- **#5** migration là file `.ts` nên được compile vào `dist/`; không cần khai báo asset.
- **#10** SQLite qua `@nestjs/typeorm`; file DB trong `.gitignore`.
- **#11** DB nằm ở máy chạy backend; đường dẫn đặt bằng `DATABASE_PATH`.
- **#12** `plan_json` là response đã trả, không có `restrictions` (F03 kiểm trong DB).
- **#16** `plan_records.id` = `plan_id` do server gán.
- **#17** test không đụng file DB thật: unit test dùng `createMemoryDataSource()`, e2e dùng `createTestApp()` (ghim `DATABASE_PATH=:memory:`).
- **#18** `createTestApp()` gọi `configureApp()`.

## Definition of Done

- [ ] `npm ls better-sqlite3` → `better-sqlite3@12.x`; `package.json` có `allowScripts` cho `better-sqlite3`
- [ ] `migrations.spec.ts`: 3 test pass (schema diff rỗng, khoá ngoại bật, `down` xoá sạch)
- [ ] `npm test` → `Test Files  10 passed (10)`, `Tests  64 passed (64)`
- [ ] `npm run test:e2e` → `Tests  12 passed (12)`; sau khi chạy, `ls backend_api/*.sqlite*` không có file nào
- [ ] `npm run build` rồi `node dist/main.js` khởi động được (không `ReferenceError`), `/health` trả 200
- [ ] `git status --short` không bao giờ hiện file `*.sqlite*`
- [x] All API routes complete within deployment timeout — không thêm route
- [x] Auth check at top of each protected handler — không áp dụng (chưa có route cần đăng nhập)

## Test Checklist

1. **@happy**: DB trong RAM chạy migration → schema khớp entity; `/health` và `generate-plan` e2e vẫn pass với DB bật
2. **@auth**: không áp dụng
3. **@timeout**: không áp dụng (không thêm route)
4. **@partial-fail**: `retryAttempts: 0` — mở DB lỗi thì khởi động thất bại ngay, không treo 27 giây vì thử lại
5. **@token**: không áp dụng
6. **@db**: migration tạo đúng bảng, cột, khoá ngoại, chỉ mục; `down` xoá sạch; khoá ngoại bật

## Tasks

### Task 1 — Cài thư viện

```bash
cd backend_api
npm install typeorm@^1.1.1 @nestjs/typeorm@^12.0.1 better-sqlite3@^12
npm install-scripts approve better-sqlite3
npm ls better-sqlite3 typeorm @nestjs/typeorm
```

Kết quả mong đợi: `better-sqlite3@12.x`, `typeorm@1.1.x`, `@nestjs/typeorm@12.0.x`; `package.json` có thêm:

```json
  "allowScripts": {
    "better-sqlite3@12.11.1": true
  }
```

(số phiên vá có thể khác). Lúc cài, npm 11 có thể cảnh báo install script chưa được duyệt — lệnh `approve` ở trên xử lý việc đó. Không thêm `@types/better-sqlite3`: code không import trực tiếp driver.

### Task 2 — Test migration trước (đỏ)

`backend_api/test/memory-data-source.ts`:

```ts
import { DataSource } from 'typeorm';
import { dataSourceOptions } from '../src/database/data-source-options.js';

// SQLite trong RAM, tạo bảng bằng đúng migration của app — test không đụng file DB thật.
export function createMemoryDataSource(): Promise<DataSource> {
  return new DataSource(dataSourceOptions(':memory:')).initialize();
}
```

`backend_api/src/database/migrations.spec.ts`:

```ts
import type { DataSource } from 'typeorm';
import { createMemoryDataSource } from '../../test/memory-data-source.js';

describe('database migrations', () => {
  let dataSource: DataSource;

  beforeEach(async () => {
    dataSource = await createMemoryDataSource();
  });

  afterEach(async () => {
    if (dataSource.isInitialized) await dataSource.destroy();
  });

  // Sửa entity mà quên viết migration → test này in ra đúng câu SQL còn thiếu.
  it('creates exactly the schema the entities describe', async () => {
    const { upQueries } = await dataSource.driver.createSchemaBuilder().log();
    expect(upQueries.map((query) => query.query)).toEqual([]);
  });

  it('enforces foreign keys, so deleting a user deletes their plans', async () => {
    expect(await dataSource.query('PRAGMA foreign_keys')).toEqual([{ foreign_keys: 1 }]);
  });

  it('reverts cleanly', async () => {
    await dataSource.undoLastMigration();
    const tables = await dataSource.query(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('users', 'plan_records')",
    );
    expect(tables).toEqual([]);
  });
});
```

```bash
npx vitest run src/database/migrations.spec.ts
```

Mong đợi: đỏ, `Cannot find module '../src/database/data-source-options.js'`.

### Task 3 — Entity, migration, cấu hình DataSource (xanh)

`backend_api/src/database/entities/user.entity.ts`:

```ts
import { Column, CreateDateColumn, Entity, OneToMany, PrimaryGeneratedColumn, type Relation } from 'typeorm';
import { PlanRecord } from './plan-record.entity.js';

// Chỉ lưu thông tin định danh từ Google — không mật khẩu, không dữ liệu sức khoẻ (NFR-5, NFR-7).
@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  // `sub` của Google ID Token; chế độ AUTH_MODE=mock dùng `mock:<email>`.
  @Column({ type: 'varchar', length: 255, unique: true })
  google_sub: string;

  @Column({ type: 'varchar', length: 320 })
  email: string;

  @Column({ type: 'varchar', length: 200 })
  name: string;

  @CreateDateColumn()
  created_at: Date;

  // Quan hệ giữa hai entity import lẫn nhau phải bọc Relation<>: nếu không, bản build ESM ghi
  // metadata kiểu (emitDecoratorMetadata) trỏ tới class chưa khởi tạo → ReferenceError lúc khởi động.
  // Vitest không bắt được lỗi này; `npm run test:smoke` chạy bản build thì bắt được.
  @OneToMany(() => PlanRecord, (plan) => plan.user)
  plans: Relation<PlanRecord[]>;
}
```

`backend_api/src/database/entities/plan-record.entity.ts`:

```ts
import { Column, Entity, Index, JoinColumn, ManyToOne, PrimaryColumn, type Relation } from 'typeorm';
import type { MealPlanResponseDto } from '../../plan/dto/meal-plan-response.dto.js';
import { User } from './user.entity.js';

@Entity('plan_records')
@Index(['user', 'created_at'])
export class PlanRecord {
  // Chính là `plan_id` do server gán trong assemblePlan() (#16).
  @PrimaryColumn({ type: 'varchar', length: 36 })
  id: string;

  @ManyToOne(() => User, (user) => user.plans, { onDelete: 'CASCADE', nullable: false })
  @JoinColumn({ name: 'user_id' })
  user: Relation<User>; // Relation<>: hai entity import lẫn nhau, xem user.entity.ts

  @Column({ type: 'varchar' })
  user_id: string;

  // Tách riêng để trả danh sách lịch sử mà không phải đọc cả JSON.
  @Column({ type: 'integer' })
  target_calories: number;

  // Đúng response đã trả cho app; response không có `restrictions` (NFR-7, #12).
  @Column({ type: 'simple-json' })
  plan_json: MealPlanResponseDto;

  // Code tự gán (mili-giây); mặc định của SQLite chỉ chính xác tới giây, hai plan liền nhau sẽ trùng giờ.
  @Column({ type: 'datetime' })
  created_at: Date;
}
```

`backend_api/src/database/migrations/1790208000000-initial-schema.ts`:

```ts
import { type MigrationInterface, type QueryRunner, Table } from 'typeorm';

// Khớp từng cột với entity — migrations.spec.ts kiểm bằng schema diff của TypeORM.
export class InitialSchema1790208000000 implements MigrationInterface {
  name = 'InitialSchema1790208000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.createTable(
      new Table({
        name: 'users',
        columns: [
          { name: 'id', type: 'varchar', isPrimary: true },
          { name: 'google_sub', type: 'varchar', length: '255', isUnique: true },
          { name: 'email', type: 'varchar', length: '320' },
          { name: 'name', type: 'varchar', length: '200' },
          { name: 'created_at', type: 'datetime', default: "datetime('now')" },
        ],
      }),
    );
    await queryRunner.createTable(
      new Table({
        name: 'plan_records',
        columns: [
          { name: 'id', type: 'varchar', length: '36', isPrimary: true },
          { name: 'target_calories', type: 'integer' },
          { name: 'plan_json', type: 'text' },
          { name: 'created_at', type: 'datetime' },
          { name: 'user_id', type: 'varchar' },
        ],
        foreignKeys: [
          {
            columnNames: ['user_id'],
            referencedTableName: 'users',
            referencedColumnNames: ['id'],
            onDelete: 'CASCADE',
          },
        ],
        indices: [{ columnNames: ['user_id', 'created_at'] }],
      }),
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.dropTable('plan_records');
    await queryRunner.dropTable('users');
  }
}
```

`backend_api/src/database/data-source-options.ts`:

```ts
import type { DataSourceOptions } from 'typeorm';
import { PlanRecord } from './entities/plan-record.entity.js';
import { User } from './entities/user.entity.js';
import { InitialSchema1790208000000 } from './migrations/1790208000000-initial-schema.js';

export const DEFAULT_DATABASE_PATH = 'database.sqlite';

// Dùng chung cho DatabaseModule và test. Không bao giờ bật `synchronize`: TypeORM có thể xoá cột
// và dữ liệu khi entity đổi. Đổi entity = viết migration mới.
export function dataSourceOptions(database: string): DataSourceOptions {
  return {
    type: 'better-sqlite3',
    database,
    entities: [User, PlanRecord],
    migrations: [InitialSchema1790208000000],
    migrationsRun: true,
    synchronize: false,
  };
}
```

```bash
npx vitest run src/database/migrations.spec.ts
```

Mong đợi: `Tests  3 passed (3)`.

### Task 4 — `DatabaseModule` và `AppModule`

`backend_api/src/database/database.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DEFAULT_DATABASE_PATH, dataSourceOptions } from './data-source-options.js';

@Module({
  imports: [
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        ...dataSourceOptions(config.get<string>('DATABASE_PATH')?.trim() || DEFAULT_DATABASE_PATH),
        // Mặc định thử lại 9 lần × 3 giây; với file SQLite, lỗi mở file không tự hết khi thử lại.
        retryAttempts: 0,
      }),
    }),
  ],
})
export class DatabaseModule {}
```

`backend_api/src/app.module.ts` (bản của F01 — F02, F03 thêm module tiếp):

```ts
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { DatabaseModule } from './database/database.module.js';
import { PlanModule } from './plan/plan.module.js';

@Module({
  imports: [ConfigModule.forRoot({ isGlobal: true }), DatabaseModule, PlanModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
```

### Task 5 — `createTestApp()` và chuyển e2e sang dùng nó

Hàm ghim luôn các biến đăng nhập (F02) và thêm sẵn `loginMock()` (dùng từ F02). Nhờ vậy file này chỉ viết một lần.

`backend_api/test/test-app.ts`:

```ts
import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { configureApp } from '../src/app.setup.js';

export interface TestApp {
  app: INestApplication;
  close: () => Promise<void>;
}

// Máy dev có thể có khoá Gemini thật, file DB thật, AUTH_MODE=google trong .env (#17):
// ghim env trước khi nạp AppModule (ConfigModule.forRoot đọc .env ngay lúc import), trả lại khi đóng.
// Mặc định: DB trong RAM, đăng nhập giả lập, không có Gemini.
export async function createTestApp(env: Record<string, string> = {}): Promise<TestApp> {
  const pinned: Record<string, string> = {
    DATABASE_PATH: ':memory:',
    AUTH_MODE: 'mock',
    GOOGLE_CLIENT_ID: '',
    JWT_SECRET: '',
    JWT_EXPIRES_IN: '',
    ALLOW_MOCK_AUTH: '',
    GEMINI_API_KEY: '',
    GEMINI_BASE_URL: '',
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
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
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

`backend_api/test/app.e2e-spec.ts` (bản của F01 — F02 thêm `auth_mode`). Test cũ chấp nhận cả `configured` lẫn `fallback` vì phụ thuộc `.env` của máy dev; giờ Gemini được ghim nên kiểm chính xác:

```ts
import request from 'supertest';
import { createTestApp, type TestApp } from './test-app.js';

describe('AppController (e2e)', () => {
  let testApp: TestApp;

  beforeAll(async () => {
    testApp = await createTestApp();
  });

  afterAll(async () => {
    await testApp.close();
  });

  it('/health (GET)', async () => {
    const res = await request(testApp.app.getHttpServer()).get('/health').expect(200);
    expect(res.body).toEqual({ status: 'ok', gemini: 'fallback' });
  });
});
```

`backend_api/test/generate-plan.e2e-spec.ts` — thay phần import và `beforeAll`/`afterAll`. Các test bên dưới giữ nguyên, trừ test Swagger: đổi `request(app.getHttpServer())` thành `request(testApp.app.getHttpServer())`. Hai file e2e bỏ luôn `import type { App } from 'supertest/types'`, vốn là lỗi kiểu có sẵn khi chạy `tsc` trên thư mục `test/`. Bản đầy đủ:

`backend_api/test/generate-plan.e2e-spec.ts`:

```ts
import { readFileSync } from 'node:fs';
import request from 'supertest';
import { startFakeGemini, type FakeGemini } from './fake-gemini-server.js';
import { createTestApp, type TestApp } from './test-app.js';

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

describe('POST /api/v1/generate-plan (e2e, SDK thật + server Gemini giả)', () => {
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

  const post = (payload: object) =>
    request(testApp.app.getHttpServer()).post('/api/v1/generate-plan').send(payload);

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
    const res = await request(testApp.app.getHttpServer()).get('/docs-json').expect(200);
    expect(res.body.components.schemas).toHaveProperty('MealPlanResponseDto');
  });
});
```

```bash
npm run test:e2e
ls *.sqlite* 2>/dev/null || echo "không có file DB"
```

Mong đợi: `Tests  12 passed (12)`, `không có file DB`.

### Task 6 — `.gitignore`, `.env.example`

Thêm vào cuối `backend_api/.gitignore`:

```
# SQLite (tài khoản + lịch sử, có thể chứa email thật khi demo — BRD NFR-5)
*.sqlite
*.sqlite-*
```

Thêm vào cuối `backend_api/.env.example`:

```
# File SQLite chứa tài khoản + lịch sử kế hoạch, tính từ thư mục chạy backend. Đã nằm trong .gitignore.
DATABASE_PATH=database.sqlite
```

### Task 7 — Cổng kiểm tra F01

```bash
cd backend_api
npm run build
npm test                 # Test Files  10 passed (10) · Tests  64 passed (64)
npm run test:e2e         # Test Files  2 passed (2) · Tests  12 passed (12)
PORT=3999 DATABASE_PATH=':memory:' node dist/main.js &   # không được có ReferenceError
sleep 3 && curl -s localhost:3999/health && kill %1
touch database.sqlite && git status --short | grep sqlite || echo "sqlite đã được ignore"; rm database.sqlite
```

Mong đợi: `{"status":"ok","gemini":"…"}` và `sqlite đã được ignore`.
