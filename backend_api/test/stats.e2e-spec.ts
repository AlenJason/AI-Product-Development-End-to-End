import { readFileSync } from 'node:fs';
import request from 'supertest';
import { DataSource } from 'typeorm';
import { GeminiCall } from '../src/stats/gemini-call.entity.js';
import { UsageDaily } from '../src/stats/usage-daily.entity.js';
import { startFakeGemini, type FakeGemini } from './fake-gemini-server.js';
import { createTestApp, loginMock, type TestApp } from './test-app.js';

// Số liệu cho trang thống kê (giai đoạn 10) — ghi thật qua HTTP → service → DB, Gemini là server giả (#17).
const SAMPLE_CONTENT: unknown = JSON.parse(readFileSync(new URL('../src/plan/data/sample-plan.json', import.meta.url), 'utf-8'));
const SECRET = 'BENH-NEN-BI-MAT-123';
const PROFILE = {
  age: 22,
  gender: 'female',
  height_cm: 168,
  weight_kg: 62,
  activity_level: 'light',
  goal: 'cut',
  restrictions: { allergies: 'Đậu phộng', injuries: '', health_conditions: SECRET },
};

describe('Số liệu thống kê (e2e)', () => {
  let testApp: TestApp;
  let fake: FakeGemini;
  const http = () => request(testApp.app.getHttpServer());
  const db = () => testApp.app.get(DataSource);
  const usage = async () =>
    Object.fromEntries((await db().getRepository(UsageDaily).find()).map((row) => [row.metric, row.count]));

  beforeAll(async () => {
    fake = await startFakeGemini();
  });

  afterAll(() => fake.close());

  afterEach(async () => {
    await testApp?.close();
  });

  it('counts a Gemini plan and logs both calls when the fallback model answers, without any personal data', async () => {
    testApp = await createTestApp({
      GEMINI_API_KEY: 'test-key',
      GEMINI_BASE_URL: fake.url,
      GEMINI_TIMEOUT_MS: '200',
      GEMINI_FALLBACK_MODEL: 'gemini-3.6-flash',
    });
    fake.reply({ kind: 'error', status: 503, message: 'This model is currently experiencing high demand.' }, { kind: 'json', body: SAMPLE_CONTENT });
    await http().post('/api/v1/generate-plan').send(PROFILE).expect(200);

    expect(await usage()).toEqual({ 'plan.gemini': 1, 'plan.guest': 1 });
    const calls = await db().getRepository(GeminiCall).find({ order: { id: 'ASC' } });
    expect(calls.map(({ task, model, attempt, outcome, http_status }) => ({ task, model, attempt, outcome, http_status }))).toEqual([
      { task: 'plan', model: 'gemini-3.5-flash', attempt: 1, outcome: 'overloaded', http_status: 503 },
      { task: 'plan', model: 'gemini-3.6-flash', attempt: 2, outcome: 'ok', http_status: null },
    ]);
    const stored = JSON.stringify([calls, await db().getRepository(UsageDaily).find()]);
    expect(stored).not.toContain(SECRET);
    expect(stored).not.toContain('Đậu phộng');
  });

  it('counts sample plans, signed-in requests, pool swaps and feedback when Gemini is off', async () => {
    testApp = await createTestApp();
    const { access_token } = await loginMock(testApp, 'lan@vku.edu.vn');
    const plan = (await http().post('/api/v1/generate-plan').set('Authorization', `Bearer ${access_token}`).send(PROFILE).expect(200)).body;
    await http().post('/api/v1/meals/swap').send({ profile: PROFILE, plan, meal_id: 'm1_1' }).expect(200);
    await http().post('/api/v1/exercises/swap').send({ profile: PROFILE, plan, exercise_id: 'e1_1' }).expect(200);
    await http()
      .post('/api/v1/feedback')
      .send({ profile: PROFILE, plan, day_number: 1, intensity: 'moderate', body_states: ['normal'], eating: 'over' })
      .expect(200);

    expect(await usage()).toEqual({
      'plan.sample': 1,
      'plan.signed_in': 1,
      'meal_swap.pool': 1,
      'exercise_swap.pool': 1,
      'feedback.total': 1,
      'feedback.unchanged': 1,
    });
    expect(await db().getRepository(GeminiCall).count()).toBe(0);
  });

  it('counts requests turned away by the rate limit', async () => {
    testApp = await createTestApp({ RATE_LIMIT_PLAN: '1/10m' });
    await http().post('/api/v1/generate-plan').send(PROFILE).expect(200);
    await http().post('/api/v1/generate-plan').send(PROFILE).expect(429);
    expect(await usage()).toMatchObject({ 'plan.guest': 1, 'rate_limited.plan': 1 });
  });
});
