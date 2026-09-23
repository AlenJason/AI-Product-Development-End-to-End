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
