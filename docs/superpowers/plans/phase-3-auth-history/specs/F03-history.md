# F03 — Lịch sử kế hoạch: lưu khi tạo plan, xem danh sách, xem lại

## Feature

BRD FR-7, mục 6.3:

- `POST /api/v1/generate-plan` dùng guard **tuỳ chọn**: không gửi header `Authorization` → chạy như khách, không lưu; token hợp lệ → lưu plan vào `plan_records`; có gửi mà token sai → 401, để app biết phải đăng nhập lại chứ không âm thầm bỏ qua việc lưu.
- Lưu lỗi (DB hỏng, đầy ổ…) → **vẫn trả plan**, thêm câu cảnh báo vào `warnings`. Người dùng không mất plan vừa tạo chỉ vì lịch sử lỗi.
- `GET /api/v1/plans/history` → tối đa 50 plan mới nhất `{ id, created_at, target_calories }`.
- `GET /api/v1/plans/history/:id` → đúng response đã trả lúc tạo. `id` không phải UUID → 400. Plan không có, hoặc là plan của người khác → **404**, để không lộ là `id` đó có tồn tại.

`plan_json` lưu đúng response, trong đó không có `restrictions` (#12). Các câu trong `warnings` là câu chung soạn sẵn (`plan-warnings.ts`), không chứa chữ người dùng nhập. E2E kiểm trực tiếp trong DB rằng chuỗi dị ứng/bệnh nền không có trong `plan_json`.

## Scope

API:

- `backend_api/src/history/dto/plan-history-response.dto.ts` (mới)
- `backend_api/src/history/history.service.ts` + `history.service.spec.ts` (mới)
- `backend_api/src/history/history.controller.ts`, `history.module.ts` (mới)
- `backend_api/test/history.e2e-spec.ts` (mới)
- `backend_api/src/plan/plan.controller.ts`, `plan.module.ts`, `plan-warnings.ts`
- `backend_api/src/app.module.ts`

## Implementation

### API Routes

| Route | Thành công | Lỗi | Latency |
|---|---|---|---|
| `POST /api/v1/generate-plan` (+ `Authorization` tuỳ chọn) | 200, như cũ; đã đăng nhập thì lưu lịch sử | 400 như cũ; 401 khi có header mà token sai | thêm 1 truy vấn xác thực + 1 `INSERT` (< 5 ms). Tổng vẫn do Gemini quyết định: chế độ mẫu ~7 ms (đo khi lập plan), tệ nhất ~30 s như giai đoạn 1 (2 lần × `GEMINI_TIMEOUT_MS`) |
| `GET /api/v1/plans/history` | 200 `{ plans: [...] }` | 401 | ~2 ms (đo khi lập plan); dùng chỉ mục `(user_id, created_at)`, tối đa 50 dòng |
| `GET /api/v1/plans/history/:id` | 200 `MealPlanResponse` | 400 không phải UUID; 401; 404 | < 5 ms |

**Auth check:** `HistoryController` gắn `@UseGuards(JwtAuthGuard)` ở cấp class, nên mọi handler đều được bảo vệ. Guard chạy trước `ParseUUIDPipe`: chưa đăng nhập thì luôn là 401, không lộ lỗi 400. `generate-plan` dùng `OptionalJwtAuthGuard`.

**Sắp xếp:** `created_at DESC, id DESC`. `created_at` chính xác tới mili-giây (F01); `id` chỉ để thứ tự luôn cố định.

### UI Components

Không có (màn hình Lịch sử ở giai đoạn 7).

### DB / KV Changes

Không đổi schema. Mỗi plan tạo khi đã đăng nhập thêm một dòng `plan_records`, `created_at = new Date()`. Không giới hạn số dòng lưu; API chỉ trả 50 dòng mới nhất.

### Ràng buộc áp dụng

- **#12** `plan_json` không chứa `restrictions`; `HistoryService` khi lỗi chỉ log thông báo lỗi DB, không log nội dung plan.
- **#16** khoá chính = `plan_id` do server gán.
- **#17** e2e chạy DB trong RAM, đăng nhập giả lập, không Gemini.
- **#18** `createTestApp()` dùng `configureApp()`.
- **#2, #7** không đụng: plan được lưu sau khi đã qua kiểm tra hợp đồng và tính danh sách đi chợ.

## Definition of Done

- [ ] `npm test` → `Test Files  15 passed (15)`, `Tests  126 passed (126)`
- [ ] `npm run test:e2e` → `Test Files  4 passed (4)`, `Tests  36 passed (36)`
- [ ] Chạy thật (`node dist/main.js` với `DATABASE_PATH` là file): đăng nhập → tạo plan → khởi động lại server → xem lại plan bằng token cũ vẫn 200
- [ ] All API routes complete within deployment timeout — history < 5 ms, generate-plan chỉ thêm < 5 ms
- [ ] Auth check at top of each protected handler — `JwtAuthGuard` trên `HistoryController`, `OptionalJwtAuthGuard` trên `generate-plan`

## Test Checklist

1. **@happy**: đăng nhập → tạo plan → danh sách có đúng `id`, `target_calories`, `created_at` ISO → xem lại bằng `id` ra đúng response lúc tạo
2. **@auth**: không token / token rác / JWT ký secret khác → 401; plan của người khác → 404 và không có trong danh sách của họ; `abc` → 400 khi đã đăng nhập, 401 khi chưa
3. **@timeout**: history < 5 ms; generate-plan không chậm hơn đáng kể
4. **@partial-fail**: bảng `plan_records` bị xoá → generate-plan vẫn 200, đủ 3 ngày, có cảnh báo "Chưa lưu được kế hoạch…"; token sai ở generate-plan → 401 và không lưu gì
5. **@token**: tài khoản đã xoá → token cũ gọi history → 401
6. **@db**: 55 plan → trả 50, mới nhất trước; hai plan cách nhau vài ms giữ đúng thứ tự; không token → không thêm dòng; `plan_json` không chứa chuỗi dị ứng/bệnh nền; xoá tài khoản → 0 dòng của người đó

## Tasks

### Task 1 — `HistoryService`: test trước

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

  it('answers an unknown id with 404', async () => {
    await expect(service.findOne(an.id, randomUUID())).rejects.toBeInstanceOf(NotFoundException);
  });
});
```

```bash
npx vitest run src/history/history.service.spec.ts   # đỏ: Cannot find module './history.service.js'
```

`backend_api/src/history/dto/plan-history-response.dto.ts`:

```ts
import { ApiProperty } from '@nestjs/swagger';

export class PlanSummaryDto {
  @ApiProperty({ format: 'uuid', description: 'plan_id của kế hoạch' })
  id: string;

  @ApiProperty({ example: '2026-09-22T10:00:00.000Z', description: 'Thời điểm tạo, ISO 8601 (UTC)' })
  created_at: string;

  @ApiProperty({ example: 1850 })
  target_calories: number;
}

export class PlanHistoryResponseDto {
  @ApiProperty({ type: [PlanSummaryDto], description: `Tối đa 50 kế hoạch, mới nhất trước` })
  plans: PlanSummaryDto[];
}
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
npx vitest run src/history/history.service.spec.ts   # Tests  6 passed (6)
```

### Task 2 — E2E lịch sử (đỏ)

`backend_api/test/history.e2e-spec.ts`:

```ts
import { JwtService } from '@nestjs/jwt';
import request from 'supertest';
import { DataSource } from 'typeorm';
import { createTestApp, loginMock, type TestApp } from './test-app.js';

const HEALTH_SECRET = 'BENH-NEN-BI-MAT-456';
const ALLERGY_SECRET = 'DI-UNG-BI-MAT-789';
const PROFILE = {
  age: 22,
  gender: 'female',
  height_cm: 168,
  weight_kg: 62,
  activity_level: 'light',
  goal: 'cut',
  restrictions: { allergies: ALLERGY_SECRET, injuries: '', health_conditions: HEALTH_SECRET },
};

describe('Lịch sử kế hoạch (e2e, AUTH_MODE=mock, DB trong RAM)', () => {
  let testApp: TestApp;
  const http = () => request(testApp.app.getHttpServer());
  const generate = (authorization?: string) => {
    const req = http().post('/api/v1/generate-plan');
    if (authorization) req.set('Authorization', authorization);
    return req.send(PROFILE);
  };
  const history = (token: string, id?: string) =>
    http()
      .get(id ? `/api/v1/plans/history/${id}` : '/api/v1/plans/history')
      .set('Authorization', `Bearer ${token}`);
  const db = () => testApp.app.get(DataSource);
  const countPlans = async (): Promise<number> =>
    (await db().query('SELECT COUNT(*) AS n FROM plan_records'))[0].n;

  beforeAll(async () => {
    testApp = await createTestApp();
  });

  afterAll(async () => {
    await testApp.close();
  });

  it('saves a plan generated while logged in and serves it back unchanged', async () => {
    const { access_token } = await loginMock(testApp, 'an@vku.edu.vn');
    const { body: plan } = await generate(`Bearer ${access_token}`).expect(200);

    const { body: list } = await history(access_token).expect(200);
    expect(list.plans[0]).toEqual({
      id: plan.plan_id,
      created_at: expect.stringMatching(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/),
      target_calories: plan.daily_target.target_calories,
    });
    const { body: saved } = await history(access_token, plan.plan_id).expect(200);
    expect(saved).toEqual(plan);
  });

  it('lists the newest plan first', async () => {
    const { access_token } = await loginMock(testApp, 'lich-su@vku.edu.vn');
    const { body: older } = await generate(`Bearer ${access_token}`).expect(200);
    await new Promise((resolve) => setTimeout(resolve, 5)); // created_at chính xác tới mili-giây
    const { body: newer } = await generate(`Bearer ${access_token}`).expect(200);
    const { body } = await history(access_token).expect(200);
    expect(body.plans.map((plan: { id: string }) => plan.id)).toEqual([newer.plan_id, older.plan_id]);
  });

  it('does not save a plan generated without a token', async () => {
    const before = await countPlans();
    await generate().expect(200);
    expect(await countPlans()).toBe(before);
  });

  it.each([
    ['a token that is not a JWT', 'Bearer not-a-jwt'],
    ['a malformed header', 'Token abc'],
  ])('rejects generate-plan with %s instead of silently skipping history', async (_label, header) => {
    const before = await countPlans();
    await generate(header).expect(401);
    expect(await countPlans()).toBe(before);
  });

  it('requires a valid token for history', async () => {
    const { user } = await loginMock(testApp, 'an@vku.edu.vn');
    const forged = await new JwtService({ secret: 'someone-elses-secret-at-least-32-chars' }).signAsync({
      sub: user.id,
    });
    await http().get('/api/v1/plans/history').expect(401);
    await history('not-a-jwt').expect(401);
    await history(forged).expect(401);
  });

  it("hides another user's plan behind 404", async () => {
    const an = await loginMock(testApp, 'an@vku.edu.vn');
    const binh = await loginMock(testApp, 'binh@vku.edu.vn');
    const { body: plan } = await generate(`Bearer ${an.access_token}`).expect(200);
    await history(binh.access_token, plan.plan_id).expect(404);
    const { body } = await history(binh.access_token).expect(200);
    expect(body.plans.map((p: { id: string }) => p.id)).not.toContain(plan.plan_id);
  });

  it('answers 400 to an id that is not a UUID, and 401 first when not logged in', async () => {
    const { access_token } = await loginMock(testApp, 'an@vku.edu.vn');
    await history(access_token, 'abc').expect(400);
    await http().get('/api/v1/plans/history/abc').expect(401);
  });

  it('never stores the health and allergy text (NFR-7, #12)', async () => {
    const { access_token } = await loginMock(testApp, 'an@vku.edu.vn');
    await generate(`Bearer ${access_token}`).expect(200);
    const rows: { plan_json: string }[] = await db().query('SELECT plan_json FROM plan_records');
    const stored = rows.map((row) => row.plan_json).join('\n');
    expect(rows.length).toBeGreaterThan(0);
    expect(stored).not.toContain(HEALTH_SECRET);
    expect(stored).not.toContain(ALLERGY_SECRET);
  });

  it('deletes the history together with the account', async () => {
    const { access_token, user } = await loginMock(testApp, 'xoa@vku.edu.vn');
    await generate(`Bearer ${access_token}`).expect(200);
    await http().delete('/api/v1/me').set('Authorization', `Bearer ${access_token}`).expect(204);

    await history(access_token).expect(401);
    const rows = await db().query('SELECT COUNT(*) AS n FROM plan_records WHERE user_id = ?', [user.id]);
    expect(rows[0].n).toBe(0);
    const again = await loginMock(testApp, 'xoa@vku.edu.vn');
    expect((await history(again.access_token).expect(200)).body).toEqual({ plans: [] });
  });

  it('documents the history endpoints in Swagger', async () => {
    const { body } = await http().get('/docs-json').expect(200);
    expect(Object.keys(body.paths)).toEqual(
      expect.arrayContaining(['/api/v1/plans/history', '/api/v1/plans/history/{id}']),
    );
    expect(body.components.schemas).toHaveProperty('PlanHistoryResponseDto');
  });
});

describe('Lưu lịch sử thất bại (e2e)', () => {
  it('still returns the plan, with a warning, when history cannot be saved', async () => {
    const testApp = await createTestApp();
    try {
      const { access_token } = await loginMock(testApp, 'an@vku.edu.vn');
      await testApp.app.get(DataSource).query('DROP TABLE plan_records');
      const { body } = await request(testApp.app.getHttpServer())
        .post('/api/v1/generate-plan')
        .set('Authorization', `Bearer ${access_token}`)
        .send(PROFILE)
        .expect(200);
      expect(body.days).toHaveLength(3);
      expect(body.warnings.some((warning: string) => warning.startsWith('Chưa lưu được kế hoạch'))).toBe(true);
    } finally {
      await testApp.close();
    }
  });
});
```

```bash
npx vitest run --config ./vitest.config.e2e.ts test/history.e2e-spec.ts   # đỏ: route chưa có (404), plan chưa được lưu
```

### Task 3 — Controller, module, nối vào `generate-plan`

`backend_api/src/history/history.controller.ts`:

```ts
import { Controller, Get, Param, ParseUUIDPipe, UseGuards } from '@nestjs/common';
import {
  ApiBadRequestResponse,
  ApiBearerAuth,
  ApiNotFoundResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
  ApiUnauthorizedResponse,
} from '@nestjs/swagger';
import { CurrentUser, JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import type { User } from '../database/entities/user.entity.js';
import { MealPlanResponseDto } from '../plan/dto/meal-plan-response.dto.js';
import { PlanHistoryResponseDto } from './dto/plan-history-response.dto.js';
import { HistoryService } from './history.service.js';

@ApiTags('history')
@ApiBearerAuth()
@ApiUnauthorizedResponse({ description: 'Chưa đăng nhập, token sai/hết hạn, hoặc tài khoản đã bị xoá' })
@UseGuards(JwtAuthGuard)
@Controller('api/v1/plans/history')
export class HistoryController {
  constructor(private readonly history: HistoryService) {}

  @Get()
  @ApiOperation({ summary: 'Danh sách kế hoạch đã tạo, mới nhất trước (BRD FR-7.2)' })
  @ApiOkResponse({ type: PlanHistoryResponseDto })
  list(@CurrentUser() user: User): Promise<PlanHistoryResponseDto> {
    return this.history.list(user.id);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Xem lại một kế hoạch (BRD FR-7.2)' })
  @ApiOkResponse({ type: MealPlanResponseDto })
  @ApiBadRequestResponse({ description: 'id không phải UUID' })
  @ApiNotFoundResponse({ description: 'Không có, hoặc thuộc tài khoản khác' })
  findOne(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string): Promise<MealPlanResponseDto> {
    return this.history.findOne(user.id, id);
  }
}
```

`backend_api/src/history/history.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module.js';
import { PlanRecord } from '../database/entities/plan-record.entity.js';
import { HistoryController } from './history.controller.js';
import { HistoryService } from './history.service.js';

@Module({
  imports: [AuthModule, TypeOrmModule.forFeature([PlanRecord])],
  controllers: [HistoryController],
  providers: [HistoryService],
  exports: [HistoryService],
})
export class HistoryModule {}
```

`backend_api/src/plan/plan-warnings.ts` — thêm vào cuối object `WARNINGS`:

```ts
  historyNotSaved:
    'Chưa lưu được kế hoạch này vào lịch sử do lỗi máy chủ. Kế hoạch vẫn dùng bình thường; muốn lưu thì tạo lại sau.',
```

`backend_api/src/plan/plan.controller.ts`:

```ts
import { Body, Controller, HttpCode, HttpStatus, Post, UseGuards } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
  ApiUnauthorizedResponse,
} from '@nestjs/swagger';
import { CurrentUser, OptionalJwtAuthGuard } from '../auth/jwt-auth.guard.js';
import type { User } from '../database/entities/user.entity.js';
import { HistoryService } from '../history/history.service.js';
import { CreatePlanDto } from './dto/create-plan.dto.js';
import { MealPlanResponseDto } from './dto/meal-plan-response.dto.js';
import { PlanService } from './plan.service.js';
import { WARNINGS } from './plan-warnings.js';

@ApiTags('plan')
@Controller('api/v1')
export class PlanController {
  constructor(
    private readonly planService: PlanService,
    private readonly history: HistoryService,
  ) {}

  @Post('generate-plan')
  @HttpCode(HttpStatus.OK)
  @UseGuards(OptionalJwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary: 'Sinh kế hoạch ăn uống & tập luyện 3 ngày (BRD FR-1, FR-2)',
    description: 'Đăng nhập là tuỳ chọn: có token hợp lệ thì kế hoạch được lưu vào lịch sử (FR-7.1).',
  })
  @ApiOkResponse({ type: MealPlanResponseDto, description: 'Kế hoạch 3 ngày theo BRD.md mục 6.2' })
  @ApiUnauthorizedResponse({ description: 'Có gửi token nhưng token sai, hết hạn, hoặc tài khoản đã bị xoá' })
  async generatePlan(
    @Body() dto: CreatePlanDto,
    @CurrentUser() user: User | undefined,
  ): Promise<MealPlanResponseDto> {
    const plan = await this.planService.generatePlan(dto);
    if (user && !(await this.history.save(user.id, plan))) {
      plan.warnings.push(WARNINGS.historyNotSaved);
    }
    return plan;
  }
}
```

`backend_api/src/plan/plan.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { HistoryModule } from '../history/history.module.js';
import { PlanController } from './plan.controller.js';
import { PlanService } from './plan.service.js';
import { GeminiService } from './gemini.service.js';

@Module({
  imports: [AuthModule, HistoryModule],
  controllers: [PlanController],
  providers: [PlanService, GeminiService],
})
export class PlanModule {}
```

`backend_api/src/app.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { AuthModule } from './auth/auth.module.js';
import { DatabaseModule } from './database/database.module.js';
import { HistoryModule } from './history/history.module.js';
import { PlanModule } from './plan/plan.module.js';

@Module({
  imports: [ConfigModule.forRoot({ isGlobal: true }), DatabaseModule, AuthModule, HistoryModule, PlanModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
```

```bash
npx vitest run --config ./vitest.config.e2e.ts test/history.e2e-spec.ts   # Tests  12 passed (12)
```

### Task 4 — Cổng kiểm tra F03

```bash
cd backend_api
npm run build
npm test                 # Test Files  15 passed (15) · Tests  126 passed (126)
npm run test:e2e         # Test Files  4 passed (4) · Tests  36 passed (36)

# Chạy thật với file DB, khởi động lại giữa chừng
rm -f smoke.sqlite
PORT=3999 DATABASE_PATH=smoke.sqlite node dist/main.js &
sleep 3
TOKEN=$(curl -s -X POST localhost:3999/api/v1/auth/google -H 'content-type: application/json' \
  -d '{"id_token":"mock:sv@vku.edu.vn"}' | node -pe 'JSON.parse(require("fs").readFileSync(0)).access_token')
PLAN_ID=$(curl -s -X POST localhost:3999/api/v1/generate-plan -H "Authorization: Bearer $TOKEN" \
  -H 'content-type: application/json' \
  -d '{"age":22,"gender":"female","height_cm":168,"weight_kg":62,"activity_level":"light","goal":"cut"}' \
  | node -pe 'JSON.parse(require("fs").readFileSync(0)).plan_id')
curl -s -w ' [%{http_code} %{time_total}s]\n' localhost:3999/api/v1/plans/history -H "Authorization: Bearer $TOKEN"
kill %1; sleep 1
PORT=3999 DATABASE_PATH=smoke.sqlite node dist/main.js &
sleep 3
curl -s -o /dev/null -w 'sau khi khởi động lại: %{http_code}\n' localhost:3999/api/v1/plans/history/$PLAN_ID \
  -H "Authorization: Bearer $TOKEN"
kill %1; rm -f smoke.sqlite
```

Mong đợi: danh sách có một plan `[200 …]`; `sau khi khởi động lại: 200`.
