import { readFileSync } from 'node:fs';
import request from 'supertest';
import { startFakeGemini, type FakeGemini } from './fake-gemini-server.js';
import { createFailingTestApp, createTestApp, type TestApp } from './test-app.js';

const SAMPLE_CONTENT: unknown = JSON.parse(
  readFileSync(new URL('../src/plan/data/sample-plan.json', import.meta.url), 'utf-8'),
);
const SECRET = 'BENH-NEN-BI-MAT-123';
const BASE = { age: 22, gender: 'female', height_cm: 168, weight_kg: 62, activity_level: 'light', goal: 'cut' };
const body = (overrides: object = {}) => ({
  ...BASE,
  // Thực đơn mẫu (dùng làm "đầu ra Gemini") không có đậu phộng, nên vẫn qua bước kiểm dị ứng.
  restrictions: { allergies: 'Đậu phộng', injuries: '', health_conditions: SECRET },
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

  // Quyết định Q4 giai đoạn 10, qua toàn bộ đường HTTP → PlanService → GeminiService → SDK → server giả.
  it('serves a Gemini plan from the fallback model when the main model is overloaded', async () => {
    const withFallback = await createTestApp({
      GEMINI_API_KEY: 'test-key',
      GEMINI_BASE_URL: fake.url,
      GEMINI_TIMEOUT_MS: '200',
      GEMINI_FALLBACK_MODEL: 'gemini-3.6-flash',
    });
    try {
      fake.reply({ kind: 'error', status: 503, message: 'This model is currently experiencing high demand.' }, { kind: 'json', body: SAMPLE_CONTENT });
      const res = await request(withFallback.app.getHttpServer()).post('/api/v1/generate-plan').send(body()).expect(200);
      expect(res.body.source).toBe('gemini');
      expect(fake.paths).toEqual(['/v1beta/models/gemini-3.5-flash:generateContent', '/v1beta/models/gemini-3.6-flash:generateContent']);
    } finally {
      await withFallback.close();
    }
  });

  it('rejects Gemini output that contains a recognised allergen, then serves the filtered sample', async () => {
    fake.reply({ kind: 'json', body: SAMPLE_CONTENT }); // thực đơn mẫu có "Nước mắm"
    const res = await post(body({ restrictions: { allergies: 'Hải sản' } })).expect(200);
    expect(fake.requests).toHaveLength(2);
    expect(res.body.source).toBe('sample');
    expect(JSON.stringify(res.body.days)).not.toMatch(/mắm|tôm/i);
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
    ['tuổi dưới 18 (v2.6.0)', { age: 17 }],
    ['mang thai nhưng giới tính nam (v2.6.0)', { gender: 'male', pregnant_or_breastfeeding: true, goal: 'maintain' }],
    ['pregnant_or_breastfeeding không phải boolean', { pregnant_or_breastfeeding: 'có' }],
  ])('rejects %s with 400', async (_label, overrides) => {
    await post(body(overrides)).expect(400);
  });

  // BRD FR-1.3 (v2.6.0): câu tiếng Việt giải thích lý do, không gọi Gemini.
  it.each([
    ['thiếu cân (BMI 16,4)', { height_cm: 160, weight_kg: 42 }, 'thiếu cân'],
    ['đang mang thai hoặc cho con bú', { pregnant_or_breastfeeding: true }, 'mang thai'],
  ])('refuses to plan a calorie deficit when %s', async (_label, overrides, reason) => {
    fake.reply({ kind: 'json', body: SAMPLE_CONTENT });
    const res = await post(body({ ...overrides, goal: 'cut' })).expect(400);
    expect(res.body.message.join(' ')).toContain(reason);
    expect(fake.requests).toHaveLength(0);
  });

  it('plans maintenance while pregnant, with the pregnancy warning and never echoing the flag back', async () => {
    fake.reply({ kind: 'json', body: SAMPLE_CONTENT });
    const res = await post(body({ goal: 'maintain', pregnant_or_breastfeeding: true })).expect(200);
    expect(res.body.warnings.join(' ')).toContain('mang thai');
    expect(JSON.stringify(res.body)).not.toContain('pregnant_or_breastfeeding');
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

describe('Cấu hình Gemini lúc khởi động (e2e)', () => {
  it('refuses to start with an unknown GEMINI_THINKING', async () => {
    await expect(createFailingTestApp({ GEMINI_THINKING: 'fast' })).rejects.toThrow(/GEMINI_THINKING/);
  });
});
