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
